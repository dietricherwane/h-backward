class MtnCisController < ApplicationController
  require 'savon'
  require 'digest'
  @@wallet_name = 'mtn_ci'
  #@@second_origin_url = Parameter.first.second_origin_url
  ##before_action :only => :guard do |o| o.filter_connections end

  # before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement, :initialize_session, :session_initialized?, :payment_result_listener, :generic_ipn_notification, :cashout, :get_sdp_notification] 
  before_action :session_exists?, only: [:index, :merchant_side_redirection, :waiting_validation, :select_layout, :guard, :set_cashout_fee, :ecommerce_payment, :build_mtn_request, :cashin_mobile, :save_cashout_log, :cashout_mobile, :check_transaction_validation, :init_index, :validate_result_parameters, :notify_to_back_office]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  # before_action :session_authenticated?, :except => [:ipn, :transaction_acknowledgement, :initialize_session, :payment_result_listener, :generic_ipn_notification, :cashout, :get_sdp_notification] 
  before_action :session_authenticated?, only: [:index, :merchant_side_redirection, :waiting_validation, :session_initialized?, :select_layout, :guard, :set_cashout_fee, :ecommerce_payment, :build_mtn_request, :cashin_mobile, :save_cashout_log, :cashout_mobile, :check_transaction_validation, :init_index, :validate_result_parameters, :notify_to_back_office]

  # Set transaction amount for GUCE requests
  before_action :set_guce_transaction_amount, :only => :index

  layout :select_layout

  def select_layout
    session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559' ? "guce" : "mtn_ci"
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

    #vérifie s'il s'agit du service ekioskmobile
    if (@service.authentication_token rescue nil) == "62c0e7c8189e0737cb036999d3994719"
      @transaction_amount = session[:trs_amount].to_f.ceil - @shipping
      session[:trs_amount] = session[:trs_amount].to_f.ceil - @shipping
    end

    set_cashout_fee

    if @basket.blank?
      @basket = MtnCi.create(
        number: session[:basket]["basket_number"], 
        service_id: session[:service].id, 
        operation_id: session[:operation].id, 
        original_transaction_amount: session[:trs_amount], 
        transaction_amount: session[:trs_amount].to_f.ceil, 
        currency_id: session[:currency].id, 
        paid_transaction_amount: @transaction_amount, 
        paid_currency_id: @wallet_currency.id, 
        transaction_id: Digest::SHA1.hexdigest([DateTime.now.iso8601(6), rand].join), 
        fees: @shipping, 
        rate: @rate, 
        login_id: session[:login_id], 
        paymoney_account_number: session[:paymoney_account_number], 
        paymoney_account_token: session[:paymoney_account_token], 
        paymoney_password: session[:paymoney_password]
      )
    else
      @basket.first.update_attributes(
        transaction_amount: session[:trs_amount], 
        original_transaction_amount: session[:trs_amount], 
        currency_id: session[:currency].id, 
        paid_transaction_amount: @transaction_amount, 
        paid_currency_id: @wallet_currency.id, 
        fees: @shipping, 
        rate: @rate, 
        login_id: session[:login_id], 
        paymoney_account_number: session[:paymoney_account_number], 
        paymoney_account_token: session[:paymoney_account_token], 
        paymoney_password: session[:paymoney_password]
      )
    end
  end

  #Méthode de paiement e-commerce
  def ecommerce_payment
    @wallet = Wallet.find_by_name("MTN Money")
    @wallet_currency = @wallet.currency
    @transaction_id = params[:transaction_id]
    @transaction_amount = params[:payment_amount].to_f.ceil
    @transaction_fee =  params[:payment_fee].to_f.ceil
    @total_amount = @transaction_amount + @transaction_fee
    @mtn_msisdn = params[:mobile_money_number]
    session[:transaction_id] = @transaction_id
    @basket = MtnCi.find_by_transaction_id(@transaction_id)
    @response_path = nil

    #Si le numéro de téléphone n'est pas vide
    if @mtn_msisdn
      if @basket
        @sdp_id = '2250110001599'
        @sdp_password = 'bmeB500'
        @timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        md5_encrypt = @sdp_id + @sdp_password + @timestamp
        @sdp_password = Digest::MD5.hexdigest(md5_encrypt)

        @request_body = build_mtn_request(1, @mtn_msisdn, @sdp_id, @sdp_password, @timestamp, @transaction_id, @total_amount, @timestamp)
        payment_request = Typhoeus::Request.new(
          "http://196.201.33.108:8310/ThirdPartyServiceUMMImpl/UMMServiceService/RequestPayment/v17",
          method: :post,
          body: @request_body,
          headers: { Accept: "text/xml" }
        )

        @basket.update_attributes(sent_request: @request_body)
        @status_code = nil
        update_wallet_used(@basket, "73007113fe")
        @response_path = ""
        payment_request.on_complete do |response|
          if response.success?
            response_code = (Nokogiri.XML(payment_request.response.body) rescue nil)
            return_array = response_code.xpath('//return')
            response_code = return_array[3].to_s
            response_code = Nokogiri.XML(response_code)
            response_code = (response_code.xpath('//value').first.text rescue nil)

            if response_code.to_s.strip == '01' || response_code.to_s.strip == '1000'
              session[:transaction_id] = @transaction_id
              @basket.update_attributes(
                process_online_client_number:     @mtn_msisdn, 
                process_online_response_code:     response_code, 
                process_online_response_message:  payment_request.response.body)
              redirect_to waiting_validation_path
            else
              @status_code = 0
              update_number_of_failed_transactions
              @basket.update_attributes(
                process_online_client_number: @mtn_msisdn, 
                process_online_response_code: response_code, 
                process_online_response_message: payment_request.response.body, 
                payment_status: false
              )
              redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
            end
          else
            @status_code = 0
            update_number_of_failed_transactions
            @basket.update_attributes(
              process_online_client_number: @mtn_msisdn, 
              process_online_response_code: response_code, 
              process_online_response_message: payment_request.response.body, 
              payment_status: false
            )
            redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
          end
        end
        payment_request.run
      else
        redirect_to error_page_path
      end
    else
      @error = true
      @error_messages = ["Veuillez entrer le numéro de téléphone"]
      initialize_customer_view("73007113fe", "ceiled_transaction_amount", "ceiled_shipping_fee")
      @phone_number_css  = @token_number_css = "row-form"
      get_service_logo(session[:service].token)
      render :index
    end
  end

  #Cashout paymoney ==> Cashin MTN Mobile Money
  def cashin_mobile
    cashin_mobile_number = params[:mobile_money_number]
    @transaction_id = params[:transaction_id]
    @transaction_amount = params[:payment_amount].to_f.ceil
    @transaction_fee =  params[:payment_fee].to_f.ceil
    @paymoney_account_number = params[:paymoney_account_number]
    @paymoney_password = params[:paymoney_password]
    @operation_token = 'e3dbe20c'
    @mobile_money_token = '5cbd715e'
    session[:transaction_id] = @transaction_id
    @basket = MtnCi.find_by_transaction_id(@transaction_id)
    @response_path = @paymoney_account_token = nil

    if cashin_mobile_number.blank?
      @error = true
      @error_messages = ["Veuillez entrer le compte à recharger"]
      initialize_customer_view("73007113fe", "ceiled_transaction_amount", "ceiled_shipping_fee")
      get_service_logo(session[:service].token)
      @basket = MtnCi.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

      render :index
    else
      if @basket
        # Cashin du compte MTN Mobile Money
        update_wallet_used(@basket, "73007113fe")
        if @paymoney_account_number
          #Vérification du compte paymoney
          paymoney_token_url = "#{Parameter.first.paymoney_wallet_url}/PAYMONEY_WALLET/rest/check2_compte/#{@paymoney_account_number}"
          @paymoney_account_token = (RestClient.get(paymoney_token_url) rescue "")

          if @paymoney_account_token.blank? || @paymoney_account_token.downcase == "null"
            redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=4&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
          else
            #Débiter le compte paymoney
            paymoney_debit_request = "#{Parameter.first.gateway_wallet_url}/api/88bc43ed59e5207c68e864564/mobile_money/cashout/Mtn/#{@operation_token}/#{@mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.paymoney_password}/#{@basket.original_transaction_amount}/#{(@basket.fees / @basket.rate).ceil.round(2)}"
            unload_response = (RestClient.get(paymoney_debit_request) rescue "")

            if unload_response.include?('|') || unload_response.blank?
              #Le compte paymoney n'a pas été débité
              @status_code = '0'
              # Update in available_wallet the number of failed_transactions
              update_number_of_failed_transactions
              @basket.update_attributes(
                payment_status: false, 
                paymoney_transaction_id: @transaction_id, 
                cashout_account_number: @paymoney_account_number
              )
              redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
            else
              @status_code = '5'
              # Update in available_wallet the number of successful_transactions
              #update_number_of_succeed_transactions
              #Créditer le compte MTN Mobile Money
              @sdp_id = '2250110001599'
              @sdp_password = 'bmeB500'
              @timestamp = Time.now.strftime('%Y%m%d%H%M%S')
              @order_time = @timestamp
              md5_encrypt = @sdp_id+@sdp_password+@timestamp
              @sdp_password = Digest::MD5.hexdigest(md5_encrypt)
              @request_body = build_mtn_request(2, cashin_mobile_number, @sdp_id, @sdp_password, @timestamp, @transaction_id, @transaction_amount.to_i, @order_time)

              deposit_request = Typhoeus::Request.new(
                "http://196.201.33.108:8310/ThirdPartyServiceUMMImpl/UMMServiceService/DepositMobileMoney/v17",
                method: :post,
                body: @request_body,
                headers: { Accept: "application/xml" }
              )

              @basket.update_attributes(sent_request: @request_body)
              @status_code = nil
              @response_path = ""
              update_wallet_used(@basket, "73007113fe")
              deposit_request.on_complete do |response|
                if response.success?
                  response_code = (Nokogiri.XML(deposit_request.response.body) rescue nil)
                  return_array = response_code.xpath('//return')
                  response_code = return_array[0].to_s
                  response_code = Nokogiri.XML(response_code)
                  response_code = (response_code.xpath('//value').first.text rescue nil)

                  if response_code.to_s.strip == '01'
                    @basket.update_attributes(
                      process_online_client_number: cashin_mobile_number, 
                      process_online_response_code: response_code, 
                      process_online_response_message: deposit_request.response.body, 
                      payment_status: true, cashout_account_number: @paymoney_account_number
                    )
                    session[:transaction_id] = @transaction_id
                    #redirect_to waiting_validation_path
                    @status_code = 5
                    update_number_of_succeed_transactions
                    @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                    redirect_to @response_path
                  else
                    update_number_of_failed_transactions

                    #Requête pour notifier au GATEWAY qu'il a eu opération de cashin mobile money
                    #C'est qu'il faudra insérer la requête DepositPayment de MTN
                    restitution_request_pm_mtn = "http://192.168.1.40:8080/PAYMONEY_WALLET/rest/remonte_vers_TRJ/c905b4c3/#{@paymoney_account_token}/5cbd715e/#{@basket.original_transaction_amount}/0/0/#{@transaction_id}"
                    restitution_request_fees = "http://192.168.1.40:8080/PAYMONEY_WALLET/rest/remonte_vers_TRJ/c905b4c3/#{@paymoney_account_token}/alOWhAgC/#{(@basket.fees / @basket.rate).ceil.round(2)}/0/0/#{@transaction_id}"
                    res1 = (RestClient.get(restitution_request_pm_mtn) rescue "")
                    res1 = res1.force_encoding('iso8859-1').encode('utf-8')
                    res2 = (RestClient.get(restitution_request_fees) rescue "")
                    res2 = res2.force_encoding('iso8859-1').encode('utf-8')

                    log = "Transaction_Id: #{@transaction_id}// restitution_request_pm_mtn: #{restitution_request_pm_mtn}// response1: #{res1}// restitution_request_fees: #{restitution_request_fees}// response2: #{res2}"
                    OmLog.create(log_rl: log)
                    @status_code = '0'
                    @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                    @basket.update_attributes(process_online_client_number: cashin_mobile_number, process_online_response_code: response_code, process_online_response_message: deposit_request.response.body, payment_status: false)
                    redirect_to @response_path
                  end
                else
                  update_number_of_failed_transactions

                  #Requête pour notifier au GATEWAY qu'il a eu opération de cashin mobile money
                  #C'est qu'il faudra insérer la requête DepositPayment de MTN
                  restitution_request_pm_mtn = "http://192.168.1.40:8080/PAYMONEY_WALLET/rest/remonte_vers_TRJ/c905b4c3/#{@paymoney_account_token}/5cbd715e/#{@basket.original_transaction_amount}/0/0/#{@transaction_id}"
                  restitution_request_fees = "http://192.168.1.40:8080/PAYMONEY_WALLET/rest/remonte_vers_TRJ/c905b4c3/#{@paymoney_account_token}/alOWhAgC/#{(@basket.fees / @basket.rate).ceil.round(2)}/0/0/#{@transaction_id}"
                  res1 = (RestClient.get(restitution_request_pm_mtn) rescue "")
                  res1 = res1.force_encoding('iso8859-1').encode('utf-8')
                  res2 = (RestClient.get(restitution_request_fees) rescue "")
                  res2 = res2.force_encoding('iso8859-1').encode('utf-8')
                  log = "Transaction_Id: #{@transaction_id}// restitution_request_pm_mtn: #{restitution_request_pm_mtn}// response1: #{res1}// restitution_request_fees: #{restitution_request_fees}// response2: #{res2}"
                  OmLog.create(log_rl: log)
                  @status_code = '0'
                  # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                  @basket.update_attributes(process_online_client_number: cashin_mobile_number, payment_status: false)
                  redirect_to notification_url(@basket, true, @@wallet_name)
                end
              end
              deposit_request.run
              #Fin condition compte paymoney debité
            end
            #Fin condition compte paymoney existe
          end
          else
            #Paramètre numéro compte paymoney nul
            # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=4&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
            redirect_to notification_url(@basket, true, @@wallet_name)
          end
          save_cashout_log
        else
          #Panier vide
          redirect_to error_page_path
        end
      end
  end

  #Cashout MTN Mobile Money ==> Cashin Paymoney
  def cashout_mobile
    @cashout_mobile_number = params[:mobile_money_number]
    @cashout_pwd = params[:token]
    @paymoney_account_number = params[:paymoney_account_number]
    @paymoney_password = params[:paymoney_password]
    @transaction_id = params[:transaction_id]
    @transaction_amount = params[:payment_amount].to_f.ceil
    @transaction_fee =  params[:payment_fee].to_f.ceil
    @total_amount = @transaction_amount+@transaction_fee
    session[:transaction_id] = @transaction_id

    @basket = MtnCi.find_by_transaction_id(@transaction_id)
    @response_path = nil

    if @cashout_mobile_number.blank?
      @error = true
      @error_messages = ["Veuillez entrer le compte à débiter"]
      initialize_customer_view("73007113fe", "ceiled_transaction_amount", "ceiled_shipping_fee")
      get_service_logo(session[:service].token)
      @basket = MtnCi.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

      render :index
    else
      if @basket
        # Cashout du compte MTN Mobile Money
        update_wallet_used(@basket, "73007113fe")
        if @paymoney_account_number
          #Vérification du compte paymoney
          paymoney_token_url = "#{Parameter.first.paymoney_wallet_url}/PAYMONEY_WALLET/rest/check2_compte/#{@paymoney_account_number}"
          @paymoney_account_token = (RestClient.get(paymoney_token_url) rescue "")
          # Si le compte PayMoney n'existe pas
          if @paymoney_account_token.blank? || @paymoney_account_token.downcase == "null"
           # redirect_to "#{session[:service].url_on_basket_already_paid}?status_id=4"
            update_number_of_failed_transactions
            @status_code = '4'
            @basket.update_attributes(
              process_online_client_number: @cashout_mobile_number, 
              process_online_response_code: response_code, 
              process_online_response_message:  payment_request.response.body, 
              payment_status: false, 
              paymoney_account_number: @paymoney_account_number
          )
            # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
            redirect_to notification_url(@basket, true, @@wallet_name)
          else
            #Débiter le compte mtn mobile money
            session[:transaction_id] = @transaction_id
            @sdp_id = '2250110001599'
            @sdp_password = 'bmeB500'
            @timestamp = Time.now.strftime('%Y%m%d%H%M%S')
            md5_encrypt = @sdp_id+@sdp_password+@timestamp
            @sdp_password = Digest::MD5.hexdigest(md5_encrypt)
            @request_body = build_mtn_request(1, @cashout_mobile_number, @sdp_id, @sdp_password, @timestamp, @transaction_id, @total_amount.to_i, @timestamp)


            payment_request = Typhoeus::Request.new(
              "http://196.201.33.108:8310/ThirdPartyServiceUMMImpl/UMMServiceService/RequestPayment/v17",
              method: :post,
              body: @request_body,
              headers: { Accept: "text/xml" }
            )

            @basket.update_attributes(sent_request: @request_body)
            @status_code = nil
            update_wallet_used(@basket, "73007113fe")
            @response_path = ""
            payment_request.on_complete do |response|
              if response.success?
                response_code = (Nokogiri.XML(payment_request.response.body) rescue nil)
                return_array = response_code.xpath('//return')
                response_code = return_array[3].to_s
                response_code = Nokogiri.XML(response_code)
                response_code = (response_code.xpath('//value').first.text rescue nil)

                if response_code.to_s.strip == '01' || response_code.to_s.strip == '1000'
                  session[:transaction_id] = @transaction_id
                  @basket.update_attributes(
                    process_online_client_number: @cashout_mobile_number, 
                    process_online_response_code: response_code, 
                    process_online_response_message:  payment_request.response.body, 
                    paymoney_account_number: @paymoney_account_number
                  )
                  redirect_to waiting_validation_path
                else
                  #Le compte MTN n'a pas été débité
                  update_number_of_failed_transactions
                  @status_code = '0'
                  # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                  @basket.update_attributes(process_online_client_number: @cashout_mobile_number, process_online_response_code: response_code, process_online_response_message:  payment_request.response.body, payment_status: false, paymoney_account_number: @paymoney_account_number)
                  redirect_to notification_url(@basket, true, @@wallet_name)
                end
              else
                # La requête de debit n'a pas abouti
                update_number_of_failed_transactions
                @status_code = '0'
                # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                @basket.update_attributes(process_online_client_number: @cashout_mobile_number, process_online_response_code: response_code, process_online_response_message:  payment_request.response.body, payment_status: false, paymoney_account_number: @paymoney_account_number)
                redirect_to notification_url(@basket, true, @@wallet_name)
              end
            end
            payment_request.run
          end
        else
          update_number_of_failed_transactions
          @status_code = '4'
          @basket.update_attributes(
            process_online_client_number: @cashout_mobile_number, 
            process_online_response_message:  payment_request.response.body, 
            payment_status: false
          )
          # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          redirect_to notification_url(@basket, true, @@wallet_name)
        end

      else
          #Panier vide
        redirect_to error_page_path
      end
    end
  end

  def get_sdp_notification
    request_message = request.body.read
    OmLog.create(log_rl: request_message.to_s)
    request_body = (Nokogiri.XML(request_message) rescue nil)
    request_body.remove_namespaces!
    @transaction_token = (request_body.xpath('//ProcessingNumber').first.text rescue nil)
    @status_code = (request_body.xpath('//StatusCode').first.text rescue nil)
    @transaction_token = @transaction_token.to_s
    @status_code = @status_code.to_s
    @result_code = @result_description = @status_info = nil

    @basket = MtnCi.find_by_transaction_id(@transaction_token)

    if @basket
      if @status_code
        if @status_code == '01'
          @result_code = '01'
          @result_description = 'SUCCESSFUL'
          @basket.update_attributes(payment_status: true)
          @status_info = 'OPERATION COMPLETED'
        else
          @result_code = '00'
          @result_description = 'FAILED'
          @status_info = 'OPERATION FAILED'
          @basket.update_attributes(payment_status: false)
        end
      else
        @result_code = '02'
        @result_description = 'INVALID PARAMETER'
        @status_info = 'StatusCode parameter is invalid'
        @basket.update_attributes(payment_status: false)
      end
    else
      @result_code = '02'
      @result_description = 'INVALID PARAMETER'
      @status_info = 'ProcessingNumber parameter is invalid'
    end

    result = %Q[
        <?xml version="1.0" encoding="utf-8"?>
        <MTNMomoTransactionResponse>
          <result>
            <resultCode xmlns="">#{@result_code}</resultCode>
            <resultDescription xmlns="">#{@result_description}</resultDescription>
          </result>
          <extensionInfo>
            <item>
              <key>resultInfo</key>
              <value>#{@status_info}</value>
            </item>
          </extensionInfo>
        </MTNMomoTransactionResponse>
      ]

    render xml: result
  end

  def merchant_side_redirection
    @transaction_id= session[:transaction_id]
    @basket = MtnCi.find_by_transaction_id(@transaction_id)
    if @basket
      #Le paiement s'est bien éffectué chez MTN
      update_wallet_used(@basket, "73007113fe")
      if @basket.payment_status == true
        if !['3d20d7af-2ecb-4681-8e4f-a585d7705423', '3d20d7af-2ecb-4681-8e4f-a585d7700ee4', '0acae92d-d63c-41d7-b385-d797b95e9855', '0acae92d-d63c-41d7-b385-d797b95e98dc', '3dcbb787-cdba-43a0-b38d-1ecda36a1e36'].include?(@basket.operation.authentication_token)
          @status_code = 1
          # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          @response_path = notification_url(@basket, true, @@wallet_name)
          #guce_request_payment?(@basket.service.authentication_token, 'QRT46FC', 'ELNPAY4')
          if (@basket.operation.authentication_token rescue nil) == "0faa5dbc-14d1-4b1a-ab85-d701cffafb58"
            @response_path = "http://ekioskmobile.net/retourabonnement.php?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          end
          update_number_of_succeed_transactions
          redirect_to @response_path
        elsif ['3d20d7af-2ecb-4681-8e4f-a585d7705423', '0acae92d-d63c-41d7-b385-d797b95e9855'].include?(@basket.operation.authentication_token)
          @status_code = 5
          update_number_of_succeed_transactions
          # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          redirect_to notification_url(@basket, true, @@wallet_name)
        elsif ['3d20d7af-2ecb-4681-8e4f-a585d7700ee4', '0acae92d-d63c-41d7-b385-d797b95e98dc'].include?(@basket.operation.authentication_token)
          @operation_token = 'a71766d6'
          @mobile_money_token = '5cbd715e'
          first_reload = "http://192.168.1.40:8080/"+"PAYMONEY_WALLET/rest/cash_in_pos/53740905/5cbd715e/#{@basket.transaction_amount.to_i}/#{@transaction_id}"
          log = "Transaction_Id: "+ @transaction_id
          log = log+"; Requête deposit: "+first_reload

          OmLog.create(log_rl: log)
          RestClient.get(first_reload)
          reload_request = "#{Parameter.first.gateway_wallet_url}/api/86d138798bc43ed59e5207c664/mobile_money/cashin/Mtn/#{@operation_token}/#{@mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.original_transaction_amount}/0"
          reload_response = (RestClient.get(reload_request) rescue "")
          status = nil
          if reload_response.include?('|') || reload_response.blank?
            @status_code = '5'
            #Échec, créditer le compte mtn débité
            # Update in available_wallet the number of failed_transactions
            update_number_of_failed_transactions
            status = false
          else
            @status_code = '1'
            update_number_of_succeed_transactions
            # Update in available_wallet the number of successful_transactions
            status = true
          end
          @basket.update_attributes(
            paymoney_reload_request: reload_request, 
            paymoney_reload_response: reload_response, 
            payment_status: status
          )
          # redirect_to  "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
          redirect_to notification_url(@basket, true, @@wallet_name)
        end
      else
        #Erreur lors de l'opération chez MTN
        if !['3d20d7af-2ecb-4681-8e4f-a585d7705423', '3d20d7af-2ecb-4681-8e4f-a585d7700ee4', '0acae92d-d63c-41d7-b385-d797b95e9855', '0acae92d-d63c-41d7-b385-d797b95e98dc', '3dcbb787-cdba-43a0-b38d-1ecda36a1e36'].include?(@basket.operation.authentication_token)
          @status_code = 0
          # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          @response_path = notification_url(@basket, true, @@wallet_name)
          #guce_request_payment?(@basket.service.authentication_token, 'QRT46FC', 'ELNPAY4')
          if (@basket.operation.authentication_token rescue nil) == "0faa5dbc-14d1-4b1a-ab85-d701cffafb58"
            @response_path = "http://ekioskmobile.net/retourabonnement.php?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          end
          redirect_to @response_path
          update_number_of_failed_transactions
        elsif ['3d20d7af-2ecb-4681-8e4f-a585d7705423', '0acae92d-d63c-41d7-b385-d797b95e9855'].include?(@basket.operation.authentication_token)
          update_number_of_failed_transactions

          #Requête pour notifier au GATEWAY qu'il a eu opération de cashin mobile money
          #C'est qu'il faudra insérer la requête DepositPayment de MTN
          restitution_request_pm_mtn = "http://192.168.1.40:8080/PAYMONEY_WALLET/rest/remonte_vers_TRJ/c905b4c3/#{@basket.paymoney_account_token}/5cbd715e/#{@basket.original_transaction_amount}/0/0/#{@transaction_id}"
          restitution_request_fees = "http://192.168.1.40:8080/PAYMONEY_WALLET/rest/remonte_vers_TRJ/c905b4c3/#{@basket.paymoney_account_token}/alOWhAgC/#{(@basket.fees / @basket.rate).ceil.round(2)}/0/0/#{@transaction_id}"
          res1 = (RestClient.get(restitution_request_pm_mtn) rescue "")
          res1 = res1.force_encoding('iso8859-1').encode('utf-8')
          res2 = (RestClient.get(restitution_request_fees) rescue "")
          res2 = res2.force_encoding('iso8859-1').encode('utf-8')
          log = "Transaction_Id: #{@transaction_id}// restitution_request_pm_mtn: #{restitution_request_pm_mtn}// response1: #{res1}// restitution_request_fees: #{restitution_request_fees}// response2: #{res2}"
          OmLog.create(log_rl: log)
          @status_code = '0'
          # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          @basket.update_attributes(payment_status: false)
          redirect_to notification_url(@basket, true, @@wallet_name)
        elsif ['3d20d7af-2ecb-4681-8e4f-a585d7700ee4', '0acae92d-d63c-41d7-b385-d797b95e98dc'].include?(@basket.operation.authentication_token)
          update_number_of_failed_transactions
          @status_code = '0'
          # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          @basket.update_attributes(payment_status: false)
          redirect_to notification_url(@basket, true, @@wallet_name)
        end
      end

    else
      redirect_to error_page_path
    end
  end

  def waiting_validation
    initialize_customer_view("73007113fe", "ceiled_transaction_amount", "ceiled_shipping_fee")
    get_service_logo(session[:service].token)
  end

  def check_transaction_validation
    @transaction_id= session[:transaction_id].to_s
    @basket = MtnCi.find_by(transaction_id: @transaction_id)
    transaction_status = "0"

    unless @basket.blank?
      unless @basket.payment_status.nil?
        transaction_status = "1"
      end
    end

    render text: transaction_status
  end

  def init_index
    initialize_customer_view("73007113fe", "ceiled_transaction_amount", "ceiled_shipping_fee")
    get_service_logo(session[:service].token)
    @phone_number_css = @token_number_css = "row-form error"
  end

  def validate_result_parameters
    if @transaction_id && @token && @clientid && @transaction_amount && (@status && @status.to_s.strip == "0")
      true
    else
      false
    end
  end

  def build_mtn_request(request_type, msisdn, sdp_id, encrypted_password, time_stamp, token_transaction, amount, order_time)
    # query_body = ""
    case request_type.to_i
    when 1
      %Q[<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:b2b="http://b2b.mobilemoney.mtn.zm_v1.0">
          <soapenv:Header>
            <RequestSOAPHeader xmlns="http://www.huawei.com.cn/schema/common/v2_1">
              <spId>#{sdp_id}</spId>
              <spPassword>#{encrypted_password}</spPassword>
              <bundleID></bundleID>
              <serviceId></serviceId>
              <timeStamp>#{time_stamp}</timeStamp>
            </RequestSOAPHeader>
          </soapenv:Header>
          <soapenv:Body>
            <b2b:processRequest>
              <serviceId>#{msisdn}@LONACIE.SDP</serviceId>
              <parameter>
                <name>DueAmount</name>
                <value>#{amount}</value>
              </parameter>
              <parameter>
                <name>MSISDNNum</name>
                <value>#{msisdn}</value>
              </parameter>
              <parameter>
                <name>ProcessingNumber</name>
                <value>#{token_transaction}</value>
              </parameter>
              <parameter>
              <name>serviceId</name>
              <value>#{msisdn}@LONACIE.SDP</value>
              </parameter>
              <parameter>
              <name>AcctRef</name>
              <value></value>
              </parameter>
              <parameter>
              <name>AcctBalance</name>
              <value></value>
              </parameter>
              <parameter>
              <name>MinDueAmount</name>
              <value></value>
              </parameter>
              <parameter>
              <name>Narration</name>
              <value></value>
              </parameter>
              <parameter>
              <name>PrefLang</name>
              <value></value>
              </parameter>
              <parameter>
              <name>OpCoID</name>
              <value>22501</value>
              </parameter>
            </b2b:processRequest>
          </soapenv:Body>
        </soapenv:Envelope>]
    when 2
      %Q[<?xml version="1.0" encoding="utf-8"?>
        <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:b2b="http://b2b.mobilemoney.mtn.zm_v1.0/">
          <SOAP-ENV:Header>
            <b2b:RequestSOAPHeader xmlns="http://www.huawei.com.cn/schema/common/v2_1">
              <b2b:spId>#{sdp_id}</b2b:spId>
              <b2b:spPassword>#{encrypted_password}</b2b:spPassword>
              <b2b:timeStamp>#{time_stamp}</b2b:timeStamp>
            </b2b:RequestSOAPHeader>
          </SOAP-ENV:Header>
          <SOAP-ENV:Body>
            <b2b:processRequest>
              <serviceId>201</serviceId>
              <parameter>
                <name>ProcessingNumber</name>
                <value>#{token_transaction}</value>
              </parameter>
              <parameter>
                <name>serviceId</name>
                <value>LONACIE.SDP</value>
              </parameter>
              <parameter>
                <name>SenderID</name>
                <value>420</value>
              </parameter>
              <parameter>
                <name>PrefLang</name>
                <value>fr</value>
              </parameter>
              <parameter>
                <name>OpCoID</name>
                <value>ic</value>
              </parameter>
              <parameter>
                <name>MSISDNNum</name>
                <value>#{msisdn}</value>
              </parameter>
              <parameter>
                <name>Amount</name>
                <value>#{amount}</value>
              </parameter>
              <parameter>
                <name>OrderDateTime</name>
                <value>#{order_time}</value>
              </parameter>
              <parameter>
                <name>CurrCode</name>
                <value>XOF</value>
              </parameter>
            </b2b:processRequest>
          </SOAP-ENV:Body>
        </SOAP-ENV:Envelope>]
    end
    # return query_body
  end

  def set_cashout_fee
    if session[:operation].authentication_token == '3d20d7af-2ecb-4681-8e4f-a585d7705423'
      fee_type = FeeType.find_by_token('0175ad')
      @shipping = 0

      if fee_type
	      @shipping = ((fee_type.fees.where("min_value <= #{session[:trs_amount].to_f} AND max_value >= #{session[:trs_amount].to_f}").first.fee_value) * @rate).ceil.round(2)
	    end
	  end
  end

  # Saves the transaction on the front office
  def save_cashout_log
    log_request = "#{Parameter.first.front_office_url}/api/856332ed59e5207c68e864564/cashout/log/orange_money_ci?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}&cashout_account_number=#{@cashout_account_number}&fee=#{@basket.fees}"
    log_response = (RestClient.get(log_request) rescue "")

    @basket.update_attributes(
      cashout_notified_to_front_office: (log_response == '1' ? true : false), 
      cashout_notification_request: log_request, 
      cashout_notification_response: log_response
    )
  end

  def ipn
    render text: params.except(:controller, :action)
  end

  def initialize_session
    @parameter = Parameter.first
    request = Typhoeus::Request.new(
      @parameter.orange_money_ci_initialization_url, 
      followlocation: true, 
      method: :post, 
      body: "merchantid=1f3e745c66347bc2cc9492d8526bfe040519396d7c98ad199f4211f39dfd6365&amount=#{@transaction_amount + (@basket.fees.ceil rescue @basket.first.fees.ceil)}&sessionid=#{@basket.transaction_id rescue @basket.first.transaction_id}&purchaseref=#{@basket.number rescue @basket.first.number}", 
      headers: {:'Content-Type' => "application/x-www-form-urlencoded"}
    )

    OmLog.create(log_rl: "OM initialization -- " + @parameter.orange_money_ci_initialization_url + "?" + "merchantid=1f3e745c66347bc2cc9492d8526bfe040519396d7c98ad199f4211f39dfd6365&amount=#{@transaction_amount + (@basket.fees.ceil rescue @basket.first.fees.ceil)}&sessionid=#{@basket.transaction_id rescue @basket.first.transaction_id}&purchaseref=#{@basket.number rescue @basket.first.number}") rescue nil

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

  def session_initialized?
    (@session_id != "access denied" && @session_id != nil && @session_id.length > 30) ? true : false
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

    basket.update_attributes(:notified_to_back_office => true) if @status.to_s.strip == "1"
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
    basket.update_attributes(:notified_to_ecommerce => true) if @response.code.to_s == "200"
  end
end
