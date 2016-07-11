class QashBasketsController < ApplicationController
  @@second_origin_url = Parameter.first.second_origin_url

  ##before_action :only => :guard do |o| o.filter_connections end
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement, :payment_result_listener, :generic_ipn_notification, :cashout]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :except => [:ipn, :transaction_acknowledgement, :payment_result_listener, :generic_ipn_notification, :cashout] do |s| s.session_authenticated? end

  # Set transaction amount for GUCE requests
  before_action :only => :index do |o| o.guce_request? end

  layout "qash"

  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end

  def index
    initialize_customer_view("936166e255", "ceiled_transaction_amount", "ceiled_shipping_fee")
    get_service_logo(session[:service].token)

    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = QashBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

    set_cashout_fee

    if @basket.blank?
      @basket = QashBasket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :original_transaction_amount => session[:trs_amount], :transaction_amount => session[:trs_amount].to_f.ceil, :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, transaction_id: Digest::SHA1.hexdigest([DateTime.now.iso8601(6), rand].join), :fees => @shipping, :rate => @rate, :login_id => session[:login_id], paymoney_account_number: session[:paymoney_account_number], paymoney_account_token: session[:paymoney_account_token], paymoney_password: session[:paymoney_password])
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount].to_f.ceil, :original_transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate, :login_id => session[:login_id], paymoney_account_number: session[:paymoney_account_number], paymoney_account_token: session[:paymoney_account_token], paymoney_password: session[:paymoney_password])
    end
  end

  def payment_result_listener
    @qash_transaction_id = params[:TXN_ID]
    @transaction_id = params[:ID_OPERATION]
    @merchant_id = params[:REF_COMMERCE]
    @transaction_amount = params[:MONTANT]
    @devise = params[:DEVISE]
    @status = params[:ETAT]
    @name = params[:NOM_PREN]

    if valid_result_parameters
      if valid_transaction
        @basket = QashBasket.find_by_transaction_id(@transaction_id)
        if @basket

          # Use Qash authentication_token
          update_wallet_used(@basket, "936166e255")

          @devise.to_s.upcase.strip == "CFA" ? (@devise = "XAF") : (@devise = nil)
          if (@basket.paid_transaction_amount + @basket.fees) == @transaction_amount.to_f  && (Currency.find_by_code(@basket.paid_currency_id).code.upcase rescue "") == @devise.upcase

            # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
            @rate = get_change_rate(@devise, "EUR")

            @basket.update_attributes(payment_status: true, qash_transaction_id: @qash_transaction_id, compensation_rate: @rate)

            @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
            @fees_for_compensation = (@basket.fees * @rate).round(2)

            # Notification au back office du hub
            notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{@basket.operation.id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")

            # Update in available_wallet the number of successful_transactions
            update_number_of_succeed_transactions

            @status_id = 1

            # Handle GUCE notifications
            guce_request_payment?(@basket.service.authentication_token, 'QRT52EC', 'ELNPAY4')

            generic_ipn_notification(@basket)

            # Cashin mobile money
            if (@basket.operation.authentication_token rescue nil) == '3d20d7af-2ecb-4681-8e4f-a585d7700ee4'
              operation_token = 'd0e39ff3'
              mobile_money_token = '02523ec1'
              reload_request = "#{Parameter.first.gateway_wallet_url}/api/86d138798bc43ed59e5207c664/mobile_money/cashin/QS/#{operation_token}/#{mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.original_transaction_amount}/0"
              reload_response = (RestClient.get(reload_request) rescue "")
              if reload_response.include?('|')
                @status_id = '5'
              end
              @basket.update_attributes(paymoney_reload_request: reload_request, paymoney_reload_response: reload_response, paymoney_transaction_id: ((reload_response.blank? || reload_response.include?('|')) ? nil : reload_response))
            end
            # Cashin mobile money

            # Redirection vers le site marchand
            redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=qash_services&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          else
            @basket.update_attributes(:conflictual_transaction_amount => @transaction_amount.to_f, :conflictual_currency => @devise.to_s[0..2].upcase)

            # Update in available_wallet the number of failed_transactions
            update_number_of_failed_transactions

            redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=qash_services&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}&id=#{@basket.login_id}"
          end
        else
          redirect_to error_page_path
        end
      else
        redirect_to error_page_path
      end
    else
      redirect_to error_page_path
    end
  end

  def valid_result_parameters
    if !@qash_transaction_id.blank? && !@transaction_id.blank? && !@transaction_amount.blank? && !@devise.blank? && !@status.blank? && !@name.blank? && !@merchant_id.blank?
      return true
    else
      return false
    end
  end

  def valid_transaction
     parameter = Parameter.first
    request = Typhoeus::Request.new("#{parameter.qash_verify_url}TXN_ID=#{@qash_transaction_id}&ID_OPERATION=#{@transaction_id}&REF_COMMERCE=#{@merchant_id}&MONTANT=#{@transaction_amount}&DEVISE=#{@devise}&ETAT=#{@status}&NOM_PREN=#{@name}", followlocation: true, method: :get)

    request.on_complete do |response|
      if response.success?
        @result = response.body.strip rescue nil
      else
        @result = nil
      end
    end

    request.run

    @result == "VERIFIED" ? true : false
  end

  def ipn
    render text: params.except(:controller, :action)
  end

  def notify_to_back_office(basket, url)
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

  # Returns 0 or 1 depending on the status of the transaction
  def transaction_acknowledgement
    generic_transaction_acknowledgement(QashBasket, params[:transaction_id])
  end

  def generic_ipn_notification(basket)
    @service = Service.find_by_id(basket.service_id)
    @request = Typhoeus::Request.new("#{@service.url_to_ipn}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=qash_services&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}", followlocation: true, method: :post)
    # wallet=05ccd7ba3d
    @request.run
    @response = @request.response
    if @response.code.to_s == "200"
      basket.update_attributes(:notified_to_ecommerce => true)
    end
  end

  def cashout
    @cashout_account_number = params[:cashout_account_number]

    @transaction_id = params[:ID_OPERATION]

    @basket = QashBasket.find_by_transaction_id(@transaction_id)

    if @cashout_account_number.blank?
      @error = true
      @error_messages = ["Veuillez entrer le compte à recharger"]
      initialize_customer_view("936166e255", "ceiled_transaction_amount", "ceiled_shipping_fee")
      get_service_logo(session[:service].token)
      @basket = QashBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

      render :index
    else
      if !@basket.blank?
        # Cashout mobile money
        operation_token = '40b29ddf'
        mobile_money_token = '02523ec1'


        unload_request = "#{Parameter.first.gateway_wallet_url}/api/88bc43ed59e5207c68e864564/mobile_money/cashout/QS/#{operation_token}/#{mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.paymoney_password}/#{@basket.original_transaction_amount}/#{(@basket.fees / @basket.rate).ceil.round(2)}"

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

        redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=qash_services&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
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
    log_request = "#{Parameter.first.front_office_url}/api/856332ed59e5207c68e864564/cashout/log/qash?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}&cashout_account_number=#{@cashout_account_number}&fee=#{@basket.fees}"
    log_response = (RestClient.get(log_request) rescue "")

    @basket.update_attributes(cashout_notified_to_front_office: (log_response == '1' ? true : false), cashout_notification_request: log_request, cashout_notification_response: log_response)
  end

end
