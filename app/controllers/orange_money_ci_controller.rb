class OrangeMoneyCiController < ApplicationController
  @@second_origin_url = Parameter.first.second_origin_url
  ##before_action :only => :guard do |o| o.filter_connections end
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement, :initialize_session, :session_initialized, :payment_result_listener, :generic_ipn_notification]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :except => [:ipn, :transaction_acknowledgement, :initialize_session, :payment_result_listener, :generic_ipn_notification] do |s| s.session_authenticated? end

  # Set transaction amount for GUCE requests
  before_action :only => :index do |o| o.guce_request? end

  #layout "orange_money_ci"

  layout :select_layout

  def select_layout
    if session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559'
      return "guce"
    else
      return "orange_money_ci"
    end
  end

  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end

  def index
    initialize_customer_view("b005fd07f0", "ceiled_transaction_amount", "ceiled_shipping_fee")
    get_service_logo(session[:service].token)

    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = OrangeMoneyCiBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

    if (@service.authentication_token rescue nil) == "62c0e7c8189e0737cb036999d3994719"
      session[:trs_amount] = session[:trs_amount].to_f.ceil - @shipping
      @transaction_amount = session[:trs_amount].to_f.ceil - @shipping
    end

    if @basket.blank?
      @basket = OrangeMoneyCiBasket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :original_transaction_amount => session[:trs_amount], :transaction_amount => session[:trs_amount].to_f.ceil, :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, transaction_id: Digest::SHA1.hexdigest([DateTime.now.iso8601(6), rand].join), :fees => @shipping, :rate => @rate, :login_id => session[:login_id])
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount].to_f.ceil, :original_transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate, :login_id => session[:login_id])
    end

    initialize_session
    unless session_initialized
      redirect_to error_page_path
    end
  end

  def payment_result_listener
    @transaction_id = params[:purchaseref]
    @token = params[:token]
    @clientid = params[:clientid]
    @transaction_amount = params[:amount]
    @status = params[:status]
    @payid = params[:payid]
    OmLog.create(log_rl: params.to_s) rescue nil

    if valid_result_parameters
      if valid_transaction
        @basket = OrangeMoneyCiBasket.find_by_transaction_id(@transaction_id)
        if @basket

          # Use Orange Money authentication_token
          update_wallet_used(@basket, "b005fd07f0")

          if (@basket.paid_transaction_amount + @basket.fees) == @transaction_amount.to_f

            # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
            @rate = get_change_rate("XAF", "EUR")

            @basket.update_attributes(payment_status: true, ompay_token: @token, ompay_clientid: @clientid, ompay_payid: @payid, compensation_rate: @rate)

            @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
            @fees_for_compensation = (@basket.fees * @rate).round(2)

            # Notification au back office du hub
            notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{@basket.operation.id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")

            # Update in available_wallet the number of successful_transactions
            update_number_of_succeed_transactions

            @status_id = 1

            # Handle GUCE notifications
            guce_request_payment?(@basket.service.authentication_token, 'QRT46FC', 'ELNPAY4')

            generic_ipn_notification(@basket)

            # Redirection vers le site marchand
            if (@basket.operation.authentication_token rescue nil) == "b6dff4ae-05c1-4050-a976-0db6e358f22b"
              redirect_to "http://ekioskmobile.net/retourabonnement.php?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=orange_money_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}".
            else
              redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=orange_money_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
            end
          else
            @basket.update_attributes(:conflictual_transaction_amount => @transaction_amount.to_f, :conflictual_currency => "XAF")

            # Update in available_wallet the number of failed_transactions
            update_number_of_failed_transactions

            if (@basket.operation.authentication_token rescue nil) == "b6dff4ae-05c1-4050-a976-0db6e358f22b"
              redirect_to "http://ekioskmobile.net/retourabonnement.php?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=orange_money_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}&id=#{@basket.login_id}"
            else
              redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=orange_money_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}&id=#{@basket.login_id}"
            end
          end
        else
          render text: "La transaction n'existe pas - H"#redirect_to error_page_path
        end
      else
        render text: "La transaction n'existe pas - O"#redirect_to error_page_path
      end
    else
      render text: "Les paramètres que vous avez envoyé sont invalides"#redirect_to error_page_path
    end
  end

  def valid_result_parameters
    if !@transaction_id.blank? && !@token.blank? && !@clientid.blank? && !@transaction_amount.blank? && (!@status.blank? && @status.to_s.strip == "0")
      return true
    else
      return false
    end
  end

  def valid_transaction
     parameter = Parameter.first
    request = Typhoeus::Request.new(parameter.orange_money_ci_verify_url, body: "merchantid=1f3e745c66347bc2cc9492d8526bfe040519396d7c98ad199f4211f39dfd6365&token=#{@token}", headers: {:'Content-Type'=> "application/x-www-form-urlencoded"}, followlocation: true, method: :post)

    request.on_complete do |response|
      if response.success?
        @result = response.body.strip rescue nil
      else
        @result = nil
      end
    end

    request.run

    OmLog.first.update_attributes(log_tv: @result.to_s) rescue nil
    /status=.*;/.match(@result).to_s.sub("status=", "")[0..0] == "0" ? true : false
  end

  def ipn
    render text: params.except(:controller, :action)
  end

  def initialize_session
    @parameter = Parameter.first
    request = Typhoeus::Request.new(@parameter.orange_money_ci_initialization_url, followlocation: true, method: :post, body: "merchantid=1f3e745c66347bc2cc9492d8526bfe040519396d7c98ad199f4211f39dfd6365&amount=#{@transaction_amount + (@basket.fees.ceil rescue @basket.first.fees.ceil)}&sessionid=#{@basket.number rescue @basket.first.number}&purchaseref=#{@basket.transaction_id rescue nil}", headers: {:'Content-Type'=> "application/x-www-form-urlencoded"})

    request.on_complete do |response|
      if response.success?
        @session_id = response.body.strip
      elsif response.timed_out?
        @session_id = nil
      elsif response.code == 0
        @session_id = nil
      else
        @session_id = nil
      end
    end

    request.run
  end

  def session_initialized
    (@session_id != "access denied" && @session_id.length > 30) ? true : false
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

  # Returns 0 or 1 depending on the status of the transaction
  def transaction_acknowledgement
    generic_transaction_acknowledgement(OrangeMoneyCiBasket, params[:transaction_id])
  end

  def generic_ipn_notification(basket)
    @service = Service.find_by_id(basket.service_id)
    @request = Typhoeus::Request.new("#{@service.url_to_ipn}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=orange_money_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}", followlocation: true, method: :post)
    # wallet=05ccd7ba3d
    @request.run
    @response = @request.response
    if @response.code.to_s == "200"
      basket.update_attributes(:notified_to_ecommerce => true)
    end
  end
end
