class PaypalController < ApplicationController
  @@second_origin_url = Parameter.first.second_origin_url
  # Only for guard action, we check if service_id exists and initialize a session variable containing transaction_data
  #before_action :only => :guard do |s| s.get_service(params[:service_id], params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Only for guard action, we check if the session varable is initialized, if the operation_id is initialized and if transaction_amount is a number
  before_action :only => :guard do |o| o.filter_connections end
  #before_action :only => :guard do |r| r.authenticate_incoming_request(params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Vérifie que le panier n'a pas déjà été payé via paypal
  #before_action :only => :guard do |s| s.basket_already_paid?(params[:basket_number]) end
  # Vérifie pour toutes les actions que la variable de session existe
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement, :cashout]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :except => [:ipn, :transaction_acknowledgement, :cashout] do |s| s.session_authenticated? end

  # Set transaction amount for GUCE requests
  before_action :only => :index do |o| o.guce_request? end

  #layout "paypal"

  layout :select_layout

  def select_layout
    if session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559'
      return "guce"
    else
      return "paypal"
    end
  end

  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end

  # Efface les parmètres du corps de la requête et affiche un friendly url dans le navigateur du client
  def index
    initialize_customer_view("e6da96e284", "unceiled_transaction_amount", "unceiled_shipping_fee")
    get_service_logo(session[:service].token)

    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = PaypalBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

    set_cashout_fee

    if @basket.blank?
      @basket = PaypalBasket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :original_transaction_amount => session[:trs_amount], :transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, transaction_id: Digest::SHA1.hexdigest([DateTime.now.iso8601(6), rand].join), :fees => @shipping, :rate => @rate, :login_id => session[:login_id], paymoney_account_number: session[:paymoney_account_number], paymoney_account_token: session[:paymoney_account_token], paymoney_password: session[:paymoney_password])
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount], :original_transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate, :login_id => session[:login_id], paymoney_account_number: session[:paymoney_account_number], paymoney_account_token: session[:paymoney_account_token], paymoney_password: session[:paymoney_password])
    end
  end

  #Instant Payment Notification de paypal, transparent pour l'utilisateur
  def ipn
    render :nothing => true, status: 200
    @gross = params[:payment_gross]
    @fees = params[:payment_fee]
    OmLog.create(log_rl: params.to_s) rescue nil
    @status = ""
    @parameters = {"cmd" => "_notify-validate"}.merge(params.except(:action, :controller))
    @request = Typhoeus::Request.new("https://www.sandbox.paypal.com/cgi-bin/webscr", followlocation: true, params: @parameters, method: :post)
    #@request = Typhoeus::Request.new("https://www.paypal.com/cgi-bin/webscr", followlocation: true, params: @parameters, method: :post)
    @request.run
    @response = @request.response
    if @response.body == "VERIFIED"
      @basket = PaypalBasket.find_by_transaction_id(params[:custom].to_s)
      if ( !@basket.blank? && (params[:payment_status] == "Completed" || params[:payment_status] == "Processed" || (params[:payment_status] == "Pending" && ["address", "authorization", "multi-currency"].include?(params[:pending_reason]))))
        # Use Paypal authentication_token
        @basket.service.available_wallets.where(wallet_id: Wallet.find_by_authentication_token("e6da96e284").id).first.update_attribute(:wallet_used, true) rescue nil

        if @basket.payment_status != true
          @basket.update_attributes(:payment_status => true)
        end
        if @basket.notified_to_back_office != true
          @rate = get_change_rate(params[:cc], "EUR")
          @@basket.update_attributes(compensation_rate: @rate)
          @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
          @fees_for_compensation = (@basket.fees * @rate).round(2)

          # Notification au back office du hub
          notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{session[:operation].id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")
        end
        # Notification au back office du ecommerce
        if @basket.notified_to_ecommerce != true
          @service = Service.find_by_id(@basket.service_id)
          @request = Typhoeus::Request.new("#{@service.url_to_ipn}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=paypal&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}", followlocation: true, method: :post)
          # wallet=e6da96e284
          @request.run
          @response = @request.response
          if @response.code.to_s == "200"
            @basket.update_attributes(:notified_to_ecommerce => true)
          end
        end
      end
    end
  end

  # Returns 0 or 1 depending on the status of the transaction
  def transaction_acknowledgement
    generic_transaction_acknowledgement(PaypalBasket, params[:transaction_id])
  end

  # Lorsque l'utilisateur finit son achat sur paypal, il est redirigé vers cette fonction pour authentifier  la transaction, l'historiser et envoyer le reporting au back end
  def payment_result_listener
    # On vérifie que les données reçues par le listener proviennent bien de paypal
    @error_messages = []
    @status = ""

    OmLog.create(log_rl: ("Paypal parameters 1: " + params.to_s)) rescue nil

    @request = Typhoeus::Request.new("https://www.sandbox.paypal.com/cgi-bin/webscr", method: :post, params: {cmd: "_notify-sync", tx: "#{params[:tx]}", at: "wc9rbATkeBqy488jdxnQeXHsv9ya8Sh6Pq_DST3BihQ4oV2-De3epJilfKG"})
    #@request = Typhoeus::Request.new("https://www.paypal.com/cgi-bin/webscr", method: :post, params: {cmd: "_notify-sync", tx: "#{params[:tx]}", at: "xGmhRanXxEiDPNYldQAjQA_uC5plNzWVCCJFb_n_Tbxk5ncfm_vlsYXls1C"})
    @request.run
    @response = @request.response

    OmLog.create(log_rl: ("Paypal parameters 2: " + @request.response.body + '--' + params.to_s)) rescue nil

    # On vérifie que la transaction a été effectuée
    if( params[:st] == "Completed" || params[:st] == "Processed" || (params[:st] == "Pending" && ["address", "authorization", "multi-currency"].include?(params[:pending_reason])) )
      @basket = PaypalBasket.find_by_transaction_id(params[:cm])
      # On vérifie que la panier existe
      if !@basket.blank?
        # On vérifie que le montant ainsi que les frais payés et la monnaie correspondent à ceux stockés dans la base de données

        # Use authentication_token to update wallet used
        update_wallet_used(@basket, "e6da96e284")

        if (@basket.paid_transaction_amount + @basket.fees) == params[:amt].to_f  and (Currency.find_by_id(@basket.paid_currency_id).code.upcase rescue "") == params[:cc].upcase
          @basket.update_attributes(:payment_status => true)

          # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
          @rate = get_change_rate(params[:cc], "EUR")
          @basket.update_attributes(compensation_rate: @rate)
          @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
          @fees_for_compensation = (@basket.fees * @rate).round(2)

          # Notification au back office du hub
          notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{session[:operation].id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")

          # Update in available_wallet the number of successful_transactions
          update_number_of_succeed_transactions

          @status_id = 1

          # Handle GUCE notifications
          guce_request_payment?(@basket.service.authentication_token, 'QRT2LS1', 'ELNPAY4')

          # Redirection vers le site marchand
          if (@basket.operation.authentication_token rescue nil) == "b6dff4ae-05c1-4050-a976-0db6e358f22b"
            redirect_to "http://ekioskmobile.net/retourabonnement.php?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=paypal&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          else

            # Cashin mobile money
            if (@basket.operation.authentication_token rescue nil) == '3d20d7af-2ecb-4681-8e4f-a585d7700ee4'
              operation_token = 'd62b4b7c'
              mobile_money_token = 'CEWlSRkn'
              reload_request = "#{Parameter.first.gateway_wallet_url}/api/86d138798bc43ed59e5207c664/mobile_money/cashin/PAYPAL/#{operation_token}/#{mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.original_transaction_amount}/0"
              reload_response = (RestClient.get(reload_request) rescue "")
              if reload_response.include?('|')
                @status_id = '5'
              end
              @basket.update_attributes(paymoney_reload_request: reload_request, paymoney_reload_response: reload_response, paymoney_transaction_id: ((reload_response.blank? || reload_response.include?('|')) ? nil : reload_response))
            end
            # Cashin mobile money

            OmLog.create(log_rl: ("Paypal parameters 3: " + "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=paypal&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}")) rescue nil
            redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=paypal&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          end
        else
          (params[:cc].length > 3) ? params[:cc][0,3] : false
          # Le montant payé ou la monnaie n'est pas celui ou celle envoyé au wallet pour ce panier
          @basket.update_attributes(:conflictual_transaction_amount => params[:amt].to_f, :conflictual_currency => params[:cc].upcase)

          # Update in available_wallet the number of failed_transactions
          update_number_of_failed_transactions

          if (@basket.operation.authentication_token rescue nil) == "b6dff4ae-05c1-4050-a976-0db6e358f22b"
            redirect_to "http://ekioskmobile.net/retourabonnement.php?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=paypal&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}&id=#{@basket.login_id}"
          else
            redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=paypal&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}&id=#{@basket.login_id}"
          end
        end
      else
        # On vérifie que le panier existe
        redirect_to error_page_path
        #redirect_to "#{session[:service].url_on_error}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0"
      end
    else
      # L'origine de la transaction n'a pas pu être vérifiée
      redirect_to error_page_path
      #redirect_to "#{session[:service].url_on_error}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0"
    end
  end

  def cashout
    @transaction_id = params[:custom]
    @cashout_account_number = params[:cashout_account_number]

    @basket = PaypalBasket.find_by_transaction_id(@transaction_id)

    if @cashout_account_number.blank?
      @error = true
      @error_messages = ["Veuillez entrer le compte à recharger"]
      initialize_customer_view("e6da96e284", "unceiled_transaction_amount", "unceiled_shipping_fee")
      get_service_logo(session[:service].token)
      @basket = PaypalBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

      render :index
    else
      if !@basket.blank?
        # Cashout mobile money
        operation_token = 'c85ee39c'
        mobile_money_token = 'CEWlSRkn'


        unload_request = "#{Parameter.first.gateway_wallet_url}/api/88bc43ed59e5207c68e864564/mobile_money/cashout/PAYPAL/#{operation_token}/#{mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.paymoney_password}/#{@basket.original_transaction_amount}/#{(@basket.fee / @basket.rate).ceil.round(2)}"

        unload_response = (RestClient.get(unload_request) rescue "")
        if unload_response.include?('|') || unload_response.blank?
          @status_id = '0'
          # Update in available_wallet the number of failed_transactions
          update_number_of_failed_transactions
          @basket.update_attributes(payment_status: false, cashout: true, cashout_completed: false, paymoney_reload_request: unload_request, paymoney_reload_response: unload_response, paymoney_transaction_id: unload_response, cashout_account_number: @cashout_account_number)
        else
          @status_id = '5'
          # Update in available_wallet the number of successful_transactions
          #update_number_of_succeed_transactions
          @basket.update_attributes(payment_status: true, cashout: true, cashout_completed: true, paymoney_reload_request: unload_request, paymoney_reload_response: unload_response, cashout_account_number: @cashout_account_number)
        end

        # Saves the transaction on the front office
        save_cashout_log

        redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=paypal&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        # Cashout mobile money
      else
        redirect_to error_page_path
      end
    end
  end

  def set_cashout_fee
    if session[:operation].authentication_token == '3d20d7af-2ecb-4681-8e4f-a585d7705423'
      fee_type = FeeType.find_by_token('0175ad')
      @shipping = 0

      if !fee_type.blank?
	      @shipping = ((fee_type.fees.where("min_value <= #{session[:trs_amount].to_f} AND max_value >= #{session[:trs_amount].to_f}").first.fee_value) * @rate).ceil.round(2)
	    end
	  end
  end

  # Saves the transaction on the front office
  def save_cashout_log
    log_request = "#{Parameter.first.front_office_url}/api/856332ed59e5207c68e864564/cashout/log/paypal?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}&cashout_account_number=#{@cashout_account_number}"
    log_response = (RestClient.get(log_request) rescue "")

    @basket.update_attributes(cashout_notified_to_front_office: (log_response == '1' ? true : false), cashout_notification_request: log_request, cashout_notification_response: log_response)
  end

  def notify_to_back_office(basket, url)
    #if basket.payment_status != true
      #basket.update_attributes(:payment_status => true)
    #end
    @request = Typhoeus::Request.new(url, followlocation: true)
    @internal_com_request = "@response = Nokogiri.XML(request.response.body)
    @response.xpath('//status').each do |link|
    @status = link.content
    end
    "
    run_typhoeus_request(@request, @internal_com_request)

    if @status.to_s.strip == "1"
      basket.update_attributes(:notified_to_back_office => true)
    end
  end

end
