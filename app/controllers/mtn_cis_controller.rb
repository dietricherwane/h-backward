class MtnCisController < ApplicationController
  @@second_origin_url = Parameter.first.second_origin_url
  ##before_action :only => :guard do |o| o.filter_connections end
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement, :initialize_session, :session_initialized, :payment_result_listener, :duke, :api_confirm_amount, :generic_ipn_notification]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :except => [:ipn, :transaction_acknowledgement, :initialize_session, :initialize_session, :payment_result_listener, :duke, :api_confirm_amount, :generic_ipn_notification] do |s| s.session_authenticated? end

  # Set transaction amount for GUCE requests
  before_action :only => :index do |o| o.guce_request? end

  layout :select_layout

  def select_layout
    if session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559'
      return "guce"
    else
      return "mtn_ci"
    end
  end

  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end

  def index
    initialize_customer_view("73007113fe", "ceiled_transaction_amount", "ceiled_shipping_fee")
    @phone_number_css  = @token_number_css = "row-form"
    get_service_logo(session[:service].token)

    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = MtnCi.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")
    if @basket.blank?
      @basket = MtnCi.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :original_transaction_amount => session[:trs_amount], :transaction_amount => session[:trs_amount].to_f.ceil, :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, transaction_id: Digest::SHA1.hexdigest([DateTime.now.iso8601(6), rand].join), :fees => @shipping, :rate => @rate, :login_id => session[:login_id], paymoney_account_number: session[:paymoney_account_number], paymoney_account_token: session[:paymoney_account_token])
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount].to_f.ceil, transaction_id: Digest::SHA1.hexdigest([DateTime.now.iso8601(6), rand].join), :original_transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate, :login_id => session[:login_id], paymoney_account_number: session[:paymoney_account_number], paymoney_account_token: session[:paymoney_account_token])
    end

    #initialize_session
    #unless session_initialized
      #redirect_to error_page_path
    #end
  end

  def initialize_payment
    @basket = MtnCi.find_by_transaction_id(params[:transaction_id])

    if valid_phone_number?(params[:colomb])
      body = %Q[<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <paymentRequest>
      <UserName>ngser</UserName>
      <Password>ngser_pas</Password>
      <Currency>XOF</Currency>
      <ReferenceInvoice>#{@basket.number}</ReferenceInvoice>
      <Amount>#{@basket.transaction_amount}</Amount>
      <ServiceFees>#{@basket.fees}</ServiceFees>
      <OperatorId>#{session[:service].authentication_token}</OperatorId>
      <GuceTransactionId>#{@basket.transaction_id}</GuceTransactionId>
      <ChannelId>11</ChannelId>
      <MobileNumber>#{params[:colomb]}</MobileNumber>
      <Token>#{params[:token]}</Token>
      </paymentRequest>]

      @basket.update_attributes(sent_request: body)

      request = Typhoeus::Request.new("http://27.34.246.91:8080/Guce/ngser/pay/PaymentRequest", body: body, followlocation: true, method: :post, headers: {'Content-Type'=> "application/xml"})

      request.on_complete do |response|
        if response.success?
          response = (Nokogiri.XML(request.response.body) rescue nil)
          response_code = (response.xpath('//paymentResponse').at('ResponseCode').content rescue nil)
          if response_code == '0000'
            @basket.update_attributes(process_online_client_number: params[:colomb], process_online_response_code: response_code, snet_init_response: request.response.body)
            session[:transaction_id] = params[:transaction_id]
            redirect_to waiting_validation_path
          else
            @error = true
            @error_messages = ["Votre transaction n'a pas été reconnue par le système"]
            @basket.update_attributes(process_online_client_number: params[:colomb], process_online_response_code: response_code, snet_init_response: request.response.body)
            init_index
            render :index
          end
        else
          @error = true
          @error_messages = ["Votre transaction n'a pas pu aboutir"]
          @basket.update_attributes(process_online_client_number: params[:colomb], snet_init_error_response: request.response.body)
          init_index
          render :index
        end
      end

      request.run
    else
      init_index
      render :index
    end
  end

  # After sending a payment request to SNET, they should check the existence of the transaction on the GPG
  def api_confirm_amount
    transaction = MtnCi.where("number = '#{params[:reference_invoice]}' AND transaction_amount = #{params[:transaction_amount]} AND transaction_id = '#{params[:transaction_id]}'")

    render xml: %Q[<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <confirmAmountResponse>
      <Status>#{transaction.blank? ? "9868" : "0000"}</Status>
      <ReferenceInvoice>#{transaction.first.number rescue nil}</ReferenceInvoice>
      <GuceTransactionId>#{transaction.first.transaction_id rescue nil}</GuceTransactionId>
      <Amount>#{transaction.first.transaction_amount rescue nil}</Amount>
      <ServiceFees>#{transaction.first.fees rescue nil}</ServiceFees>
      </confirmAmountResponse>]
  end



  def waiting_validation
    initialize_customer_view("73007113fe", "ceiled_transaction_amount", "ceiled_shipping_fee")
    get_service_logo(session[:service].token)
  end

  def check_transaction_validation
    order = MtnCi.find_by_transaction_id(session[:transaction_id])
    transaction_status = "0"

    if order
      if order.payment_status
        transaction_status = "1"
      end
    end

    render text: transaction_status
  end

  def redirect_to_merchant_website
    order = MtnCi.find_by_transaction_id(session[:transaction_id])

    # Redirection vers le site marchand
    #redirect_to "#{order.service.url_on_success}?transaction_id=#{order.transaction_id}&order_id=#{order.number}&status_id=1&wallet=mtn_ci&transaction_amount=#{order.original_transaction_amount}&currency=#{order.currency.code}&paid_transaction_amount=#{order.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(order.paid_currency_id).code}&change_rate=#{order.rate}&id=#{order.login_id}"

    if (order.operation.authentication_token rescue nil) == "b6dff4ae-05c1-4050-a976-0db6e358f22b"
      redirect_to "http://ekioskmobile.net/retourabonnement.php?transaction_id=#{order.transaction_id}&order_id=#{order.number}&status_id=1&wallet=mtn_ci&transaction_amount=#{order.original_transaction_amount}&currency=#{order.currency.code}&paid_transaction_amount=#{order.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(order.paid_currency_id).code}&change_rate=#{order.rate}&id=#{order.login_id}"
    else

      # Cashin mobile money
      if (@basket.operation.authentication_token rescue nil) == '3d20d7af-2ecb-4681-8e4f-a585d7700ee4'
        mobile_money_token = 'a71766d6'
        reload_request = "#{Parameter.first.gateway_wallet_url}/api/86d138798bc43ed59e5207c664/mobile_money/cashin/#{mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.original_transaction_amount}/0"
        reload_response = (RestClient.get(reload_request) rescue "")
        if reload_response.include?('|')
          @status_id = '5'
        end
        @basket.update_attributes(paymoney_reload_request: reload_request, paymoney_reload_response: reload_response, paymoney_transaction_id: ((reload_response.blank? || reload_response.include?('|')) ? nil : reload_response))
      end
      # Cashin mobile money

      redirect_to "#{order.service.url_on_success}?transaction_id=#{order.transaction_id}&order_id=#{order.number}&status_id=#{@status_id}&wallet=mtn_ci&transaction_amount=#{order.original_transaction_amount}&currency=#{order.currency.code}&paid_transaction_amount=#{order.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(order.paid_currency_id).code}&change_rate=#{order.rate}&id=#{order.login_id}"
    end
  end

  def init_index
    initialize_customer_view("73007113fe", "ceiled_transaction_amount", "ceiled_shipping_fee")
    get_service_logo(session[:service].token)
    @phone_number_css = @token_number_css = "row-form error"
  end

  def payment_result_listener
    @user_name = params[:user_name]
    @password = params[:password]
    @number = params[:reference_invoice]
    @transaction_id = params[:guce_transaction_id]
    @status = params[:status]
    @transaction_amount = params[:paid_amount]
    @fee = params[:paid_fee]
    @login_id = params[:txn_id]
    @real_time_code = params[:real_time_code]
    @real_time_numfacture = params[:real_time_numfacture]
    @real_time_datefacture = params[:real_time_datefacture]
    @real_time_delaipaiement = params[:real_time_delaipaiement]
    @real_time_montant = params[:real_time_montant]
    @real_time_ch_str_xx = params[:real_time_ch_str_xx]
    @real_time_ch_long_xx = params[:real_time_ch_long_xx]
    @real_time_ch_date_xx = params[:real_time_ch_date_xx]
    @real_time_ch_money_xx = params[:real_time_ch_money_xx]
    @real_time_transact = params[:real_time_transact]
    OmLog.create(log_rl: params.to_s) rescue nil

    status = ''

    if valid_authentication
      if valid_transaction
        # Use MTN Money authentication_token
        update_wallet_used(@basket, "73007113fe")
        status = '0000'
        if @status == '0000'

          # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
          @rate = get_change_rate("XAF", "EUR")

          MtnCi.find_by_transaction_id(@transaction_id).update_attributes(params.merge({payment_status: true, compensation_rate: @rate, snet_payment_response: params.to_s}))

          @amount_for_compensation = ((@transaction.first.paid_transaction_amount + @transaction.first.fees) * @rate).round(2)
          @fees_for_compensation = (@transaction.first.fees * @rate).round(2)

          # Notification au back office du hub
          notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{@transaction.first.operation.id}/#{@transaction.first.number}/#{@transaction.first.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")

          # Update in available_wallet the number of successful_transactions
          update_number_of_succeed_transactions

          # Handle GUCE notifications
          @basket = @transaction.first
          guce_request_payment?(@transaction.first.service.authentication_token, 'QRT0FDD', 'ELNPAY4')
        else
          # Update in available_wallet the number of failed_transactions
          update_number_of_failed_transactions

          MtnCi.find_by_transaction_id(@transaction_id).update_attributes(params.merge({payment_status: false, snet_payment_error_response: params.to_s}))
        end
      else
        status = '9568'
      end
    else
       status = '0102'
    end

    render xml: %Q[<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <ConfirmPaymentResponse>
      <Status>#{status}</Status>
      <ReferenceInvoice>#{@number}</ReferenceInvoice>
      <GuceTransactionId>#{@transaction_id}</GuceTransactionId>
      <PaidAmount>#{@transaction_amount}</PaidAmount>
      <ServiceFees>#{@fee}</ServiceFees>
      <TxnId>#{@login_id}</TxnId>
      <RealTimeCode>#{@real_time_code}</RealTimeCode>
      <RealTimeNumfacture>#{@real_time_numfacture}</RealTimeNumfacture>
      <RealTimeDatefacture>#{@real_time_datefacture}</RealTimeDatefacture>
      <RealTimeDelaiPaiement>#{@real_time_delaipaiement}</RealTimeDelaiPaiement>
      <RealTimeMontant>#{@real_time_montant}</RealTimeMontant>
      <RealTimeChStr>#{@real_time_ch_str_xx}</RealTimeChStr>
      <RealTimeChLong>#{@real_time_ch_long_xx}</RealTimeChLong>
      <RealTimeChDate>#{@real_time_ch_date_xx}</RealTimeChDate>
      <RealTimeChMoney>#{@real_time_ch_money_xx}</RealTimeChMoney>
      <RealTimeTransact>#{@real_time_transact}</RealTimeTransact>
      </ConfirmPaymentResponse>]
  end

  # Authenticates incoming request according to provided credentials [user_name, password]
  def valid_authentication
    if @user_name == "6d544d9a-a912-4921-b8c0-ef64251ec814" && @password == "0a2d16022896"
      return true
    else
      return false
    end
  end

  # Validates the given parameters and check the existence of TxnId
  def valid_transaction
    @basket = @transaction = MtnCi.where("number = '#{@number}' AND transaction_id = '#{@transaction_id}' AND transaction_amount = #{@transaction_amount} AND fees = #{@fee}")

    if @transaction.blank?
      return false
    else
      return true
    end
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
    generic_transaction_acknowledgement(MtnCi, params[:transaction_id])
  end

  def valid_phone_number?(phone_number)
    if phone_number.blank? || not_a_number?(phone_number) || phone_number.length != 8
      @error = true
      @error_messages = ["Le numéro de téléphone doit être valide et de 8 chiffres.", "Votre code de sécurité doit être valide."]
      return false
    else
      return true
    end
  end

def generic_ipn_notification(basket)
    @service = Service.find_by_id(basket.service_id)
    @request = Typhoeus::Request.new("#{@service.url_to_ipn}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}", followlocation: true, method: :post)
    # wallet=05ccd7ba3d
    @request.run
    @response = @request.response
    if @response.code.to_s == "200"
      basket.update_attributes(:notified_to_ecommerce => true)
    end
  end

end
