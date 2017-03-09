class MtnCisController < ApplicationController
  require 'savon'
  require 'digest'

  # include Wallets::MTNMoMo

  @@wallet_name = 'mtn_ci'
  ##before_action :only => :guard do |o| o.filter_connections end
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement, :initialize_session, :session_initialized, :payment_result_listener, :generic_ipn_notification, :cashout, :get_sdp_notification, :mtn_deposit_from_ussd, :mtn_payment_from_ussd]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :except => [:ipn, :transaction_acknowledgement, :initialize_session, :payment_result_listener, :generic_ipn_notification, :cashout, :get_sdp_notification, :mtn_deposit_from_ussd, :mtn_payment_from_ussd] do |s| s.session_authenticated? end

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
    @wallet = Wallet.find_by_name("MTN Money")
    @wallet_currency = @wallet.currency

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
        transaction_id: generate_transaction_id,
        fees: @shipping,
        rate: @rate,
        login_id: session[:login_id],
        paymoney_account_number: session[:paymoney_account_number],
        paymoney_account_token: session[:paymoney_account_token]
      )
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount], :original_transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate, :login_id => session[:login_id], paymoney_account_number: session[:paymoney_account_number], paymoney_account_token: session[:paymoney_account_token])
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
    unless @mtn_msisdn.blank?
      if !@basket.blank?
        # @request_body = build_mtn_request(1, @mtn_msisdn, @transaction_id, @total_amount)
        # payment_request = request_to_send(1, @request_body)
        #########  Début Modification  #########
        @payment = Wallets::Mtnmomo.new(
          msisdn: @mtn_msisdn,
          processing_number: @transaction_id,
          due_amount: @total_amount
        )
        response = @payment.unload
        @basket.update_attributes(
          # sent_request: @payload,
          sent_request: response.request.path.to_s,
          phone_number: @mtn_msisdn,
          type_token: 'WEB'
        )
        @status_code = nil
        update_wallet_used(@basket, "73007113fe")

        ### Processing based on former request result ###
        # Successful request
        if response.code == 200
          response_code = Nokogiri.XML(response.body)
          return_array = response_code.xpath('//return')
          response_code = return_array[3].to_s
          response_code = Nokogiri.XML(response_code)
          response_code = response_code.xpath('//value').first.text
          ### Checking StatusCode ###
          # Successful transaction
          if response_code.to_s.strip == '01' || response_code.to_s.strip == '1000'
            session[:transaction_id] = @transaction_id
            @basket.update_attributes(
              process_online_response_code: response_code,
              process_online_response_message: response.body
            )
            redirect_to waiting_validation_path
          else # Failed transaction
            @status_code = 0
            update_number_of_failed_transactions
            @basket.update_attributes(
              process_online_response_code: response_code,
              process_online_response_message: response.body,
              payment_status: false
            )
            redirect_to notification_url(@basket, true, @@wallet_name)
            # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
          end
        else # Failed request
          @status_code = 0
          update_number_of_failed_transactions
          @basket.update_attributes(
            process_online_response_code: response_code,
            payment_status: false,
            process_online_response_message: response.body,
          )
          redirect_to notification_url(@basket, true, @@wallet_name)
          # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        end
        ######### Fin Modification  #########

        # @basket.update_attributes(sent_request: @request_body, phone_number: @mtn_msisdn, type_token: 'WEB')
        # @status_code = nil
        # update_wallet_used(@basket, "73007113fe")
        # @response_path = ""
        # payment_request.on_complete do |response|
        #   if response.success?
        #     response_code = (Nokogiri.XML(payment_request.response.body) rescue nil)
        #     return_array = response_code.xpath('//return')
        #     response_code = return_array[3].to_s
        #     response_code = Nokogiri.XML(response_code)
        #     response_code = (response_code.xpath('//value').first.text rescue nil)
        #
        #     if response_code.to_s.strip == '01' || response_code.to_s.strip == '1000'
        #       session[:transaction_id] = @transaction_id
        #       @basket.update_attributes(process_online_response_code: response_code, process_online_response_message:   payment_request.response.body)
        #       redirect_to waiting_validation_path
        #     else
        #       @status_code = 0
        #       update_number_of_failed_transactions
        #       @basket.update_attributes(
        #         process_online_response_code: response_code,
        #         process_online_response_message: payment_request.response.body,
        #         payment_status: false
        #       # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        #       )
        #       redirect_to notification_url(@basket, true, @@wallet_name)
        #     end
        #   else
        #     @status_code = 0
        #     update_number_of_failed_transactions
        #     @basket.update_attributes(
        #       process_online_response_code: response_code,
        #       payment_status: false,
        #       process_online_response_message: payment_request.response.body,
        #     # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        #     )
        #     redirect_to notification_url(@basket, true, @@wallet_name)
        #   end
        # end
        # payment_request.run
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
      if !@basket.blank?
        @basket.update_attributes(phone_number: @cashin_mobile_number, type_token: 'WEB')
        # Cashin du compte MTN Mobile Money
        update_wallet_used(@basket, "73007113fe")
        if @paymoney_account_number
          #Vérification du compte paymoney
          paymoney_token_url = "#{ENV['paymoney_wallet_url']}/PAYMONEY_WALLET/rest/check2_compte/#{@paymoney_account_number}"
          @paymoney_account_token = (RestClient.get(paymoney_token_url) rescue "")

          if @paymoney_account_token.blank? || @paymoney_account_token.downcase == "null"
            # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=4&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
            redirect_to notification_url(@basket, true, @@wallet_name)
          else
            #Débiter le compte paymoney
            paymoney_debit_request = "#{ENV['gateway_wallet_url']}/api/88bc43ed59e5207c68e864564/mobile_money/cashout/Mtn/#{@operation_token}/#{@mobile_money_token}/#{@basket.paymoney_account_number}/#{@paymoney_password}/#{@basket.transaction_id}/#{@basket.original_transaction_amount}/#{(@basket.fees / @basket.rate).ceil.round(2)}"
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
              # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
              redirect_to notification_url(@basket, true, @@wallet_name)
            else
              @status_code = '5'
              # Update in available_wallet the number of successful_transactions
              #update_number_of_succeed_transactions
              #Créditer le compte MTN Mobile Money

              # @request_body = build_mtn_request(2, @cashin_mobile_number, @transaction_id, @transaction_amount.to_i)
              # deposit_request= request_to_send(2, @request_body)
              @payment = Wallets::Mtnmomo.new(
                msisdn: @cashin_mobile_number,
                processing_number: @transaction_id,
                due_amount: @transaction_amount.to_i
              )
              response = @payment.reload

              @basket.update_attributes(sent_request: @request_body)
              update_wallet_used(@basket, "73007113fe")

              ### Processing based on former request result ###
              # Successful request
              if response.code == 200
                response_code = (Nokogiri.XML(response.body) rescue nil)
                return_array = response_code.xpath('//return')
                mom_transaction_code = return_array[2].to_s
                mom_transaction_code = Nokogiri.XML(mom_transaction_code)
                mom_transaction_code = (mom_transaction_code.xpath('//value').first.text rescue nil)
                response_code = return_array[0].to_s
                response_code = Nokogiri.XML(response_code)
                response_code = (response_code.xpath('//value').first.text rescue nil)
                ### Checking StatusCode ###
                # Successful transaction
                if response_code.to_s.strip == '01'
                  @basket.update_attributes(
                    process_online_response_code: response_code,
                    process_online_response_message: response.body,
                    payment_status: true,
                    cashout_account_number: @cashin_mobile_number,
                    paymoney_account_number: @paymoney_account_number,
                    cashout: true,
                    cashout_completed: true,
                    mom_transaction_id: mom_transaction_code
                  )
                  session[:transaction_id] = @transaction_id
                  @status_code = 1
                  update_number_of_succeed_transactions
                  save_cashout_log(@basket, @cashin_mobile_number)
                  # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                  # redirect_to @response_path
                  redirect_to notification_url(@basket, true, @@wallet_name)
                else # Failed transaction
                  update_number_of_failed_transactions

                  #Requête pour notifier au GATEWAY qu'il a eu opération de cashin mobile money
                  #C'est qu'il faudra insérer la requête DepositPayment de MTN
                  restitution_request_pm_mtn = "#{ENV['mtn_restitution_request_url']}/#{@paymoney_account_token}/5cbd715e/#{@basket.original_transaction_amount}/0/0/#{@transaction_id}"
                  restitution_request_fees = "#{ENV['mtn_restitution_request_url']}/#{@paymoney_account_token}/alOWhAgC/#{(@basket.fees / @basket.rate).ceil.round(2)}/0/0/#{@transaction_id}"
                  res1 = (RestClient.get(restitution_request_pm_mtn) rescue "")
                  res1 = res1.force_encoding('iso8859-1').encode('utf-8')
                  res2 = (RestClient.get(restitution_request_fees) rescue "")
                  res2 = res2.force_encoding('iso8859-1').encode('utf-8')

                  log = "Transaction_Id: #{@transaction_id}// restitution_request_pm_mtn: #{restitution_request_pm_mtn}// response1: #{res1}// restitution_request_fees: #{restitution_request_fees}// response2: #{res2}"
                  OmLog.create(log_rl: log)
                  @status_code = '0'
                  # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                  @basket.update_attributes(
                    process_online_response_code: response_code,
                    process_online_response_message: response.body,
                    payment_status: false,
                    mom_transaction_id: mom_transaction_code
                  )
                  # redirect_to @response_path
                  redirect_to notification_url(@basket, true, @@wallet_name)
                end
              else # Failed request
                update_number_of_failed_transactions

                #Requête pour notifier au GATEWAY qu'il a eu opération de cashin mobile money
                #C'est qu'il faudra insérer la requête DepositPayment de MTN
                restitution_request_pm_mtn = "#{ENV['mtn_restitution_request_url']}/#{@paymoney_account_token}/5cbd715e/#{@basket.original_transaction_amount}/0/0/#{@transaction_id}"
                restitution_request_fees = "#{ENV['mtn_restitution_request_url']}/#{@paymoney_account_token}/alOWhAgC/#{(@basket.fees / @basket.rate).ceil.round(2)}/0/0/#{@transaction_id}"
                res1 = (RestClient.get(restitution_request_pm_mtn) rescue "")
                res1 = res1.force_encoding('iso8859-1').encode('utf-8')
                res2 = (RestClient.get(restitution_request_fees) rescue "")
                res2 = res2.force_encoding('iso8859-1').encode('utf-8')
                log = "Transaction_Id: #{@transaction_id}// restitution_request_pm_mtn: #{restitution_request_pm_mtn}// response1: #{res1}// restitution_request_fees: #{restitution_request_fees}// response2: #{res2}"
                OmLog.create(log_rl: log)
                @status_code = '0'
                # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                @basket.update_attributes(
                  process_online_client_number: cashin_mobile_number,
                  payment_status: false
                )
                redirect_to notification_url(@basket, true, @@wallet_name)
              end
              #Fin condition compte paymoney debité
            end
            #Fin condition compte paymoney existe
          end
        else
          #Paramètre numéro compte paymoney nul
          # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=4&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
          redirect_to notification_url(@basket, true, @@wallet_name)
        end
        #save_cashout_log
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
    @total_amount = @transaction_amount
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
        @basket.update_attributes(
          phone_number: @cashout_mobile_number,
          type_token: 'WEB',
          fees: @transaction_fee
        )
        update_wallet_used(@basket, "73007113fe")
        if @paymoney_account_number
          #Vérification du compte paymoney
          paymoney_token_url = "#{ENV['paymoney_wallet_url']}/PAYMONEY_WALLET/rest/check2_compte/#{@paymoney_account_number}"
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

            # @request_body = build_mtn_request(1, @cashout_mobile_number, @transaction_id, @total_amount.to_i)
            # payment_request = request_to_send(1, @request_body)

            @payment = Wallets::Mtnmomo.new(
              msisdn: @cashout_mobile_number,
              processing_number: @transaction_id,
              due_amount: @total_amount.to_i
            )
            response = @payment.unload

            @basket.update_attributes(sent_request: response.request.options)
            update_wallet_used(@basket, "73007113fe")

            ### Processing based on former request result ###
            # Successful request
            if response.code == 200
              response_code = Nokogiri.XML(response.body)
              return_array = response_code.xpath('//return')
              response_code = return_array[3].to_s
              response_code = Nokogiri.XML(response_code)
              response_code = response_code.xpath('//value').first.text
              ### Checking StatusCode ###
              # Successful transaction
              if response_code.to_s.strip == '01' || response_code.to_s.strip == '1000'
                session[:transaction_id] = @transaction_id
                @basket.update_attributes(
                  process_online_response_code: response_code,
                  process_online_response_message:  response.body,
                  paymoney_account_number: @paymoney_account_number
                )
                redirect_to waiting_validation_path
              else # Failed transaction
                #Le compte MTN n'a pas été débité
                update_number_of_failed_transactions
                @status_code = '0'
                # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                @basket.update_attributes(
                  process_online_client_number: @cashout_mobile_number,
                  process_online_response_code: response_code,
                  process_online_response_message:  response.body,
                  payment_status: false,
                  paymoney_account_number: @paymoney_account_number
                )
                redirect_to notification_url(@basket, true, @@wallet_name)
              end
            else # Failed request
              # La requête de debit n'a pas abouti
              update_number_of_failed_transactions
              @status_code = '0'
              # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
              @basket.update_attributes(
                process_online_client_number: @cashout_mobile_number,
                process_online_response_code: response_code,
                process_online_response_message:  response.body,
                payment_status: false,
                paymoney_account_number: @paymoney_account_number
              )
              redirect_to notification_url(@basket, true, @@wallet_name)
            end
          end
        else
          update_number_of_failed_transactions
          @status_code = '4'
          @basket.update_attributes(
            process_online_client_number: @cashout_mobile_number,
            process_online_response_message:  response.body,
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
    @mom_transaction_id = (request_body.xpath('//MOMTransactionID').first.text rescue nil)
    @transaction_token = @transaction_token.to_s
    @transaction_token = @transaction_token.strip
    @status_code = @status_code.to_s
    @result_code = @result_description = @status_info = nil


    @basket = MtnCi.find_by_transaction_id(@transaction_token)

    if (!@basket.blank?) && (@basket.type_token == 'USSD')
      if @status_code == '01'
        @operation_token = 'a71766d6'
        @mobile_money_token = '5cbd715e'
        first_reload = "#{ENV['mtn_cash_in_pos_url']}/#{@basket.transaction_amount.to_i}/#{@transaction_token}"
        log = 'USSD-Transaction_Id: #{@transaction_token} StatusCode: #{@status_code} MOMTransactionID #{@mom_transaction_id}'
        log = log+"; Requête deposit: "+first_reload

        OmLog.create(log_rl: log)
        RestClient.get(first_reload)
        reload_request = "#{ENV['gateway_wallet_url']}/api/86d138798bc43ed59e5207c664/mobile_money/cashin/Mtn/#{@operation_token}/#{@mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.transaction_id}/#{@basket.original_transaction_amount}/0"
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
        @basket.update_attributes(paymoney_reload_request: reload_request, paymoney_reload_response: reload_response, payment_status: status, mom_transaction_id: @mom_transaction_id)

        @result_code = '01'
        @result_description = 'SUCCESSFUL'

        @status_info = 'OPERATION COMPLETED'
      else
        update_number_of_failed_transactions
      #  @status_code = '0'
        #@response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
        @basket.update_attributes(payment_status: false)
        @result_code = '00'
        @result_description = 'FAILED'
        @status_info = 'OPERATION FAILED'
        #redirect_to @response_path
      end
    else
      unless @basket.blank?
        unless @status_code.blank?
          if @status_code == '01'
            @result_code = '01'
            @result_description = 'SUCCESSFUL'
            @basket.update_attributes(payment_status: true, mom_transaction_id: @mom_transaction_id)
            @status_info = 'OPERATION COMPLETED'
          else
            @result_code = '00'
            @result_description = 'FAILED'
            @status_info = 'OPERATION FAILED'
            @basket.update_attributes(payment_status: false, mom_transaction_id: @mom_transaction_id)
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
          # Paiement e-commerce
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
          # Déchargement PayMoney
          @status_code = 5
          update_number_of_succeed_transactions
          # @response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
          redirect_to notification_url(@basket, true, @@wallet_name)
        elsif ['3d20d7af-2ecb-4681-8e4f-a585d7700ee4', '0acae92d-d63c-41d7-b385-d797b95e98dc'].include?(@basket.operation.authentication_token)
          # Rechargement PayMoney
          @operation_token = 'a71766d6'
          @mobile_money_token = '5cbd715e'
          first_reload = "#{ENV['mtn_cash_in_pos_url']}/#{@basket.transaction_amount.to_i}/#{@transaction_id}"
          log = "Transaction_Id: "+ @transaction_id
          log = log+"; Requête deposit: "+first_reload

          OmLog.create(log_rl: log)
          RestClient.get(first_reload)
          reload_request = "#{ENV['gateway_wallet_url']}/api/86d138798bc43ed59e5207c664/mobile_money/cashin/Mtn/#{@operation_token}/#{@mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.transaction_id}/#{@basket.original_transaction_amount}/0"
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
          # Paiement e-commerce
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
          # Déchargement PayMoney
          update_number_of_failed_transactions

          #Requête pour notifier au GATEWAY qu'il a eu opération de cashin mobile money
          #C'est qu'il faudra insérer la requête DepositPayment de MTN
          restitution_request_pm_mtn = "#{ENV['mtn_restitution_request_url']}/#{@basket.paymoney_account_token}/5cbd715e/#{@basket.original_transaction_amount}/0/0/#{@transaction_id}"
          restitution_request_fees = "#{ENV['mtn_restitution_request_url']}/#{@basket.paymoney_account_token}/alOWhAgC/#{(@basket.fees / @basket.rate).ceil.round(2)}/0/0/#{@transaction_id}"
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
          # Rechargement PayMoney
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

  # TODO Must be placed in API namespace
  # Cashout paymoney ==> Cashin MTN Mobile Money
  def mtn_deposit_from_ussd # cashin
    service_token = params[:service_token]
    reload_token = params[:operation_token]
    msisdn = params[:msisdn]
    basket_number = params[:basket_number]
    transaction_amount = params[:transaction_amount]
    currency = params[:currency]
    fee =nil
    paymoney_account_number = params[:paymoney_account_number]
    @paymoney_password = params[:paymoney_password]
    @operation_token = 'e3dbe20c'
    @mobile_money_token = '5cbd715e'
    paymoney_transaction_number= Time.now.to_i.to_s
    paymoney_transaction_number = generate_random_token(3)+paymoney_transaction_number
    paymoney_account_token = nil
    @return_code = nil

    @service_ussd = Service.find_by(authentication_token: service_token)
    @operation_ussd = Operation.find_by(authentication_token: reload_token)
    currency = Currency.find_by(code: currency)
    if valid_ussd_parameter?(msisdn, basket_number, transaction_amount, paymoney_account_number) == true
      fee = get_paymoney_fees(transaction_amount.to_f)
      @basket_ussd = MtnCi.create(number: basket_number, service_id: @service_ussd.id, operation_id: @operation_ussd.id, original_transaction_amount: transaction_amount.to_f, transaction_amount: transaction_amount.to_f.ceil, currency_id: currency.id, paid_transaction_amount: transaction_amount.to_f, paid_currency_id: currency.id, transaction_id: paymoney_transaction_number, paymoney_account_number: paymoney_account_number, cashout_account_number: msisdn, phone_number: msisdn, type_token: 'USSD')
      unless fee.nil?
        @basket_ussd.update_attributes(fees: fee.fee_value)
      end
      paymoney_token_url = "#{ENV['paymoney_wallet_url']}/PAYMONEY_WALLET/rest/check2_compte/#{paymoney_account_number}"
      paymoney_account_token = (RestClient.get(paymoney_token_url) rescue "")

      if paymoney_account_token.blank? || paymoney_account_token.downcase == "null"
        @return_code = -1
      else
        paymoney_debit_request = "#{ENV['gateway_wallet_url']}/api/88bc43ed59e5207c68e864564/mobile_money/cashout/Mtn/#{@operation_token}/#{@mobile_money_token}/#{@basket_ussd.paymoney_account_number}/#{@paymoney_password}/#{@basket_ussd.transaction_id}/#{@basket_ussd.original_transaction_amount}/#{(@basket_ussd.fees).ceil.round(2)}"
        unload_response = (RestClient.get(paymoney_debit_request) rescue "")

        if unload_response.include?('|') || unload_response.blank?
          #Le compte paymoney n'a pas été débité
          @return_code = -1
          # Update in available_wallet the number of failed_transactions
          update_number_of_failed_transactions
          @basket_ussd.update_attributes(payment_status: false, cashout_account_number: paymoney_account_number)
          #redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        else
          #Créditer le compte MTN Mobile Money

          request_body = build_mtn_request(2, msisdn, paymoney_transaction_number, transaction_amount.to_i)
          deposit_request = request_to_send(2, request_body)

          @basket_ussd.update_attributes(sent_request: request_body)

          update_wallet_used(@basket_ussd, "73007113fe")
          deposit_request.on_complete do |response|
            if response.success?
              response_code = (Nokogiri.XML(deposit_request.response.body) rescue nil)
              return_array = response_code.xpath('//return')
              mom_transaction_code = return_array[2].to_s
              mom_transaction_code = Nokogiri.XML(mom_transaction_code)
              mom_transaction_code = (mom_transaction_code.xpath('//value').first.text rescue nil)
              response_code = return_array[0].to_s
              response_code = Nokogiri.XML(response_code)
              response_code = (response_code.xpath('//value').first.text rescue nil)

              if response_code.to_s.strip == '01'
                @basket_ussd.update_attributes(cashout_account_number: paymoney_account_number, process_online_response_code: response_code, process_online_response_message: deposit_request.response.body, payment_status: true, cashout: true, cashout_completed: true, mom_transaction_id: mom_transaction_code)

                #redirect_to waiting_validation_path
                @return_code = 1
                @status_code  = 1
                update_number_of_succeed_transactions
                save_cashout_log(@basket_ussd, msisdn)

              else
                update_number_of_failed_transactions

                #Requête pour notifier au GATEWAY qu'il a eu opération de cashin mobile money
                #C'est qu'il faudra insérer la requête DepositPayment de MTN
                restitution_request_pm_mtn = "#{ENV['mtn_restitution_request_url']}/#{paymoney_account_token}/5cbd715e/#{@basket_ussd.original_transaction_amount}/0/0/#{paymoney_transaction_number}"
                restitution_request_fees = "#{ENV['mtn_restitution_request_url']}/#{paymoney_account_token}/alOWhAgC/#{(@basket_ussd.fees).ceil.round(2)}/0/0/#{paymoney_transaction_number}"
                res1 = (RestClient.get(restitution_request_pm_mtn) rescue "")
                res1 = res1.force_encoding('iso8859-1').encode('utf-8')
                res2 = (RestClient.get(restitution_request_fees) rescue "")
                res2 = res2.force_encoding('iso8859-1').encode('utf-8')

                log = "Transaction_Id: #{@transaction_id}// restitution_request_pm_mtn: #{restitution_request_pm_mtn}// response1: #{res1}// restitution_request_fees: #{restitution_request_fees}// response2: #{res2}"
                OmLog.create(log_rl: log)
                @return_code = 0
                #@response_path = "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_code}&wallet=mtn_ci&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
                @basket_ussd.update_attributes(cashout_account_number: paymoney_account_number, process_online_response_code: response_code, process_online_response_message: deposit_request.response.body, payment_status: false, cashout: false, cashout_completed: false, mom_transaction_id: mom_transaction_code)
              end
            else
              update_number_of_failed_transactions

              #Requête pour notifier au GATEWAY qu'il a eu opération de cashin mobile money
              #C'est qu'il faudra insérer la requête DepositPayment de MTN
              restitution_request_pm_mtn = "#{ENV['mtn_restitution_request_url']}/#{paymoney_account_token}/5cbd715e/#{@basket_ussd.original_transaction_amount}/0/0/#{paymoney_transaction_number}"
              restitution_request_fees = "#{ENV['mtn_restitution_request_url']}/#{paymoney_account_token}/alOWhAgC/#{(@basket_ussd.fees).ceil.round(2)}/0/0/#{paymoney_transaction_number}"
              res1 = (RestClient.get(restitution_request_pm_mtn) rescue "")
              res1 = res1.force_encoding('iso8859-1').encode('utf-8')
              res2 = (RestClient.get(restitution_request_fees) rescue "")
              res2 = res2.force_encoding('iso8859-1').encode('utf-8')

              log = "Transaction_Id: #{@transaction_id}// restitution_request_pm_mtn: #{restitution_request_pm_mtn}// response1: #{res1}// restitution_request_fees: #{restitution_request_fees}// response2: #{res2}"
              OmLog.create(log_rl: log)
              @return_code = 0
              @basket_ussd.update_attributes(cashout_account_number: paymoney_account_number, payment_status: false, cashout: false, cashout_completed: false)
            end
          end
          deposit_request.run
          #Fin condition compte paymoney debité
        end
      end
    else
      @return_code = -1
    end

    render :text => @return_code
  end

  # TODO Must be placed in API namespace
  #Cashout MTN Mobile Money ==> Cashin Paymoney
  #Méthode de cashin USSD
  def mtn_payment_from_ussd # cashout
    service_token = params[:service_token]
    reload_token = params[:operation_token]
    msisdn = params[:msisdn]
    basket_number = params[:basket_number]
    transaction_amount = params[:transaction_amount]
    currency = params[:currency]
    fee =nil
    paymoney_account_number = params[:paymoney_account_number]

    @operation_token = 'e3dbe20c'
    @mobile_money_token = '5cbd715e'
    paymoney_transaction_number = Time.now.to_i.to_s
    paymoney_transaction_number = generate_random_token(3)+paymoney_transaction_number

    paymoney_account_token = nil
    @return_code = nil

    @service_ussd = Service.find_by(authentication_token: service_token)
    @operation_ussd = Operation.find_by(authentication_token: reload_token)
    currency = Currency.find_by(code: currency)

    if valid_ussd_parameter?(msisdn, basket_number, transaction_amount, paymoney_account_number)
      @basket_ussd = MtnCi.create(number: basket_number, service_id: @service_ussd.id, operation_id: @operation_ussd.id, original_transaction_amount: transaction_amount.to_f, transaction_amount: transaction_amount.to_f.ceil, currency_id: currency.id, paid_transaction_amount: transaction_amount.to_f, paid_currency_id: currency.id, transaction_id: paymoney_transaction_number, paymoney_account_number: paymoney_account_number, phone_number: msisdn, type_token: 'USSD')
      update_wallet_used(@basket_ussd, "73007113fe")
        #Vérification du compte paymoney
        paymoney_token_url = "#{ENV['paymoney_wallet_url']}/PAYMONEY_WALLET/rest/check2_compte/#{paymoney_account_number}"
        paymoney_account_token = (RestClient.get(paymoney_token_url) rescue "")

        if paymoney_account_token.blank? || paymoney_account_token.downcase == "null"
         # redirect_to "#{session[:service].url_on_basket_already_paid}?status_id=4"
         update_number_of_failed_transactions
         @return_code = -1
        else
          #Débiter le compte mtn mobile money
          request_body = build_mtn_request(1, msisdn, paymoney_transaction_number, transaction_amount.to_i)

          payment_request = request_to_send(1, request_body)
          @basket_ussd.update_attributes(sent_request: request_body)
          update_wallet_used(@basket, "73007113fe")
          payment_request.on_complete do |response|
            if response.success?
              response_code = (Nokogiri.XML(payment_request.response.body) rescue nil)
              return_array = response_code.xpath('//return')
              response_code = return_array[3].to_s
              response_code = Nokogiri.XML(response_code)
              response_code = (response_code.xpath('//value').first.text rescue nil)

              if response_code.to_s.strip == '01' || response_code.to_s.strip == '1000'
                @basket_ussd.update_attributes(process_online_response_code: response_code, process_online_response_message:  payment_request.response.body, paymoney_account_number: paymoney_account_number)
                case response_code.to_s.strip
                when '01'
                  @return_code = 1
                when '1000'
                  @return_code = 2
                end

              else
                #Le compte MTN n'a pas été débité
                update_number_of_failed_transactions
                @return_code = 0
                @basket_ussd.update_attributes(process_online_response_code: response_code, process_online_response_message:  payment_request.response.body, payment_status: false, paymoney_account_number: paymoney_account_number)
              end
            else
              #La requête de debit n'a pas abouti
              update_number_of_failed_transactions
              @return_code = 0
              @basket_ussd.update_attributes(payment_status: false, paymoney_account_number: paymoney_account_number)
            end
          end
          payment_request.run
        end
      else
        update_number_of_failed_transactions
        @return_code = -1
        @basket_ussd.update_attributes(payment_status: false, paymoney_account_number: paymoney_account_number)
      end

    render :text => @return_code
  end

  def valid_phone_number?(n)
    validity = (Integer(n) != nil rescue false)
    if validity == true && n.length == 11
      true
    else
      false
    end
  end

  def valid_numeric?(n)
    Float(n) != nil rescue false
  end

  def generate_random_token(len)
    chars_source = %w{ 0 1 2 3 4 5 6 7 8 9}
    code = (0...len).map{ chars_source.to_a[rand(chars_source.size)] }.join
    return code
  end

  def valid_ussd_parameter?(msisdn, transaction_id, amount, paymoney_account_number)
    unless (msisdn.nil? || transaction_id.nil? || amount.nil? || paymoney_account_number.nil?)
      if valid_phone_number?(msisdn) == true && valid_numeric?(amount) ==true
        true
      else
        false
      end
    else
      false
    end
  end

  def get_paymoney_fees(amount)

    fee = nil
    down_fee = Fee.where("min_value<= ?", amount).last
    if !down_fee.nil?
      if down_fee.max_value >= amount
        fee = down_fee
      end
    end

    return fee
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

  # def request_to_send(request_type, request_body)
  #   url_to_post = nil
  #
  #   case request_type
  #   when 1
  #     url_to_post = Typhoeus::Request.new(
  #             ENV['mtn_payment_request_url'],
  #             method: :post,
  #             body: request_body,
  #             headers: { Accept: "text/xml" }
  #           )
  #   when 2
  #     url_to_post = Typhoeus::Request.new(
  #               ENV['mtn_deposit_request_url'],
  #               method: :post,
  #               body: request_body,
  #               headers: { Accept: "application/xml" }
  #             )
  #   end
  #
  #   return url_to_post
  # end

  #Construction du corps de la requête à envoyer au SDP MTN

  # def build_mtn_request(request_type, msisdn, token_transaction, amount)
  #   query_body = ""
  #   sdp_id = ENV['mtn_sdp_id']
  #   sdp_password = ENV['mtn_sdp_password']
  #   @timestamp = Time.now.strftime('%Y%m%d%H%M%S')
  #   md5_encrypt = sdp_id+sdp_password+@timestamp
  #   sdp_password = Digest::MD5.hexdigest(md5_encrypt)
  #   case request_type.to_i
  #   when 1
  #     query_body = %Q[<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:b2b="http://b2b.mobilemoney.mtn.zm_v1.0">
  #                     <soapenv:Header>
  #                       <RequestSOAPHeader xmlns="http://www.huawei.com.cn/schema/common/v2_1">
  #                         <spId>#{sdp_id}</spId>
  #                         <spPassword>#{sdp_password}</spPassword>
  #                         <bundleID></bundleID>
  #                         <serviceId></serviceId>
  #                         <timeStamp>#{@timestamp}</timeStamp>
  #                       </RequestSOAPHeader>
  #                     </soapenv:Header>
  #                     <soapenv:Body>
  #                       <b2b:processRequest>
  #                         <serviceId>#{msisdn}@LONACIE.SDP</serviceId>
  #                         <parameter>
  #                           <name>DueAmount</name>
  #                           <value>#{amount}</value>
  #                         </parameter>
  #                         <parameter>
  #                           <name>MSISDNNum</name>
  #                           <value>#{msisdn}</value>
  #                         </parameter>
  #                         <parameter>
  #                           <name>ProcessingNumber</name>
  #                           <value>#{token_transaction}</value>
  #                         </parameter>
  #                         <parameter>
  #                         <name>serviceId</name>
  #                         <value>#{msisdn}@LONACIE.SDP</value>
  #                         </parameter>
  #                         <parameter>
  #                         <name>AcctRef</name>
  #                         <value></value>
  #                         </parameter>
  #                         <parameter>
  #                         <name>AcctBalance</name>
  #                         <value></value>
  #                         </parameter>
  #                         <parameter>
  #                         <name>MinDueAmount</name>
  #                         <value></value>
  #                         </parameter>
  #                         <parameter>
  #                         <name>Narration</name>
  #                         <value></value>
  #                         </parameter>
  #                         <parameter>
  #                         <name>PrefLang</name>
  #                         <value></value>
  #                         </parameter>
  #                         <parameter>
  #                         <name>OpCoID</name>
  #                         <value>22501</value>
  #                         </parameter>
  #                       </b2b:processRequest>
  #                     </soapenv:Body>
  #                   </soapenv:Envelope>]
  #   when 2
  #     query_body = %Q[<?xml version="1.0" encoding="utf-8"?>
  #                     <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:b2b="http://b2b.mobilemoney.mtn.zm_v1.0/">
  #                     <SOAP-ENV:Header><b2b:RequestSOAPHeader xmlns="http://www.huawei.com.cn/schema/common/v2_1">
  #                     <b2b:spId>#{sdp_id}</b2b:spId>
  #                     <b2b:spPassword>#{sdp_password}</b2b:spPassword>
  #                     <b2b:timeStamp>#{@timestamp}</b2b:timeStamp>
  #                     </b2b:RequestSOAPHeader>
  #                     </SOAP-ENV:Header>
  #                     <SOAP-ENV:Body>
  #                     <b2b:processRequest>
  #                     <serviceId>201</serviceId>
  #                     <parameter>
  #                     <name>ProcessingNumber</name>
  #                     <value>#{token_transaction}</value>
  #                     </parameter>
  #                     <parameter>
  #                     <name>serviceId</name>
  #                     <value>LONACIE.SDP</value>
  #                     </parameter>
  #                     <parameter>
  #                     <name>SenderID</name>
  #                     <value>420</value>
  #                     </parameter>
  #                     <parameter>
  #                     <name>PrefLang</name>
  #                     <value>fr</value>
  #                     </parameter>
  #                     <parameter>
  #                     <name>OpCoID</name>
  #                     <value>ic</value>
  #                     </parameter>
  #                     <parameter>
  #                     <name>MSISDNNum</name>
  #                     <value>#{msisdn}</value>
  #                     </parameter>
  #                     <parameter>
  #                     <name>Amount</name>
  #                     <value>#{amount}</value>
  #                     </parameter>
  #                     <parameter>
  #                     <name>OrderDateTime</name>
  #                     <value>#{@timestamp}</value>
  #                     </parameter>
  #                     <parameter>
  #                     <name>CurrCode</name>
  #                     <value>XOF</value>
  #                     </parameter>
  #                     </b2b:processRequest>
  #                     </SOAP-ENV:Body>
  #                     </SOAP-ENV:Envelope>]
  #   end
  #   # return query_body
  # end

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
  def save_cashout_log(basket, cashin_mobile_number)
    log_request = "#{ENV['front_office_url']}/api/856332ed59e5207c68e864564/cashout/log/mtn_ci?transaction_id=#{basket.transaction_id}&order_id=#{basket.number}&status_id=#{@status_code}&transaction_amount=#{basket.original_transaction_amount}&currency=#{basket.currency.code}&paid_transaction_amount=#{basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(basket.paid_currency_id).code}&change_rate=#{basket.rate}&id=#{basket.login_id}&cashout_account_number=#{cashin_mobile_number}&fee=#{basket.fees}"
    log_response = (RestClient.get(log_request) rescue "")

    @basket.update_attributes(
      cashout_notified_to_front_office: (log_response == '1' ? true : false),
      cashout_notification_request: log_request,
      cashout_notification_response: log_response
    )
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

  def ipn
    render text: params.except(:controller, :action)
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
    generic_transaction_acknowledgement(MtnCi, params[:transaction_id])
  end
end
