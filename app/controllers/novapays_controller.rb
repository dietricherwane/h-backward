require 'net/http'

class NovapaysController < ApplicationController
  @@wallet_name = 'biao'
  @@second_origin_url = Parameter.first.second_origin_url
  ##before_action :only => :guard do |o| o.filter_connections end
  before_action :session_exists?, :only => [:index, :select_layout, :guard, :set_cashout_fee, :valid_transaction, :notify_to_back_office, :save_cashout_log]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :session_authenticated?, :only => [:index, :select_layout, :guard, :set_cashout_fee, :valid_transaction, :notify_to_back_office, :save_cashout_log]

  # Set transaction amount for GUCE requests
  before_action :set_guce_transaction_amount, :only => :index

  layout :select_layout

  def select_layout
    session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559' ? "guce" : "novapay"
  end

  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end

  def index
    initialize_customer_view("77e26b3cbd", "ceiled_transaction_amount", "ceiled_shipping_fee")
    get_service_logo(session[:service].token)

    # Si le panier n'existe pas on en crée un nouveau sinon on met à jour les nouvelles informations (le montant, la monnaie envoyés par le ecommerce ainsi que le montant, la monnaie et les frais à envoyer au ecommerce)
    @basket = Novapay.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

    set_cashout_fee

    if @basket.blank?
      @basket = Novapay.create(
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
        transaction_amount: session[:trs_amount].to_f.ceil, 
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

  # Redirect to NovaPay platform
  def process_payment
    OmLog.create(log_rl: %Q[_identify=3155832361,_password=#{Digest::MD5.hexdigest('3155832361' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '44680')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')}])
    request = Typhoeus::Request.new(
      "http://novaplus.ci/novapay/novapay.awp", 
      method:         :post, 
      body:           %Q[{"_descprod": "#{params[:service_name]}", "_refact": "#{params[:_refact]}", "_prix": "#{params[:_prix]}" }], 
      headers:        { 
        'QUERY-STRING' => %Q[_identify=3155832361,_password=#{Digest::MD5.hexdigest('3155832361' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '44680')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')}]
      }, 
      followlocation: true, 
      ssl_verifypeer: false, 
      ssl_verifyhost: 0
    )
    # str = %Q[https://novaplus.ci/NOVAPAY_WEB/FR/novapay.awp | body: {"_descprod": "#{params[:service_name]}", "_refact": "#{params[:_refact]}", "_prix": "#{params[:_prix]}"} headers: { 'QUERY_STRING' => _identify=3155832361,_password=#{Digest::MD5.hexdigest('3155832361' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '44680')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')}}]
    request.run
    response = request.response

    render text: response.body
  end

  def payment_result_listener
    @refact = params[:refac].strip
    @refoper = params[:refoper].strip
    @status = params[:status].strip
    @mtnt = params[:mtnt].strip
    OmLog.create(log_rl: params.to_s + "method: #{request.get? ? 'GET' : 'POST'}") rescue nil
    @request_type = request
    #valid_transaction
    if validate_result_parameters
      if valid_transaction || request.get?
        @basket = Novapay.find_by_number(@refact)
        if @basket
          # Use NovaPay authentication_token
          update_wallet_used(@basket, "77e26b3cbd")
          request.post? ? @status = "1" : nil
          if (@status.to_s.downcase.strip == "1" || @status.to_s.downcase.strip == "succes")
            # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
            @rate = get_change_rate("XAF", "EUR")
            if request.post?
              @basket.update_attributes(
                payment_status: true, 
                refoper: @refoper, 
                compensation_rate: @rate
              )
            end
            @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
            @fees_for_compensation = (@basket.fees * @rate).round(2)

            if request.post?
              # Notification au back office du hub
              notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{@basket.operation.id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")

              OmLog.create(log_rl: "Notification à paymoney: " + "#{@@second_origin_url}/GATEWAY/rest/WS/#{@basket.operation.id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")

              # Update in available_wallet the number of successful_transactions
              update_number_of_succeed_transactions
              # Handle GUCE notifications
              guce_request_payment?(@basket.service.authentication_token, 'QRTGH78', 'VIECOB8')
              render text: "0"
            else
              @status_id = '1'

              # Cashin mobile money
              if ['3d20d7af-2ecb-4681-8e4f-a585d7700ee4', '0acae92d-d63c-41d7-b385-d797b95e98dc', '7489bd19-6ef8-4748-8218-ac9201512345', 'ebb1f4f3-116b-417e-8348-5964771d0123', 's8g56da9-63f1-486e-9b0c-eceb0aab6d6c'].include?(@basket.operation.authentication_token)
                operation_token = '1be8397d'
                mobile_money_token = 'ffce3241'
                reload_request = "#{Parameter.first.gateway_wallet_url}/api/86d138798bc43ed59e5207c664/mobile_money/cashin/Nsia/#{operation_token}/#{mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.original_transaction_amount}/0"
                reload_response = (RestClient.get(reload_request) rescue "")
                if reload_response.include?('|')
                  @status_id = '5'
                end
                @basket.update_attributes(paymoney_reload_request: reload_request, paymoney_reload_response: reload_response, paymoney_transaction_id: ((reload_response.blank? || reload_response.include?('|')) ? nil : reload_response))
              end
              # Cashin mobile money

              # Redirection vers le site marchand
              # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=biao&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
              redirect_to notification_url(@basket, true, @@wallet_name)
            end
          else
            if request.post?
              @basket.update_attributes(payment_status: false, refoper: @refoper)

              # Update in available_wallet the number of failed_transactions
              update_number_of_failed_transactions
              render text: "1"
            else
              # redirect_to "#{@basket.service.url_on_error}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=biao&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}&id=#{@basket.login_id}"
              redirect_to notification_url(@basket, false, @@wallet_name)
            end
          end
        else
          if request.post?
            render text: "2"#"order id not found" + @refac
          else
            #redirect_to error_page_path
            render text: "order id not found" + @refac.to_s
          end
        end
      else
        if request.post?
          render text: "3"#"transaction non trouvée: " + @result
        else
          #redirect_to error_page_path
          render text: "transaction non trouvée: " + @result
        end
      end
    else
      if request.post?
        render text: "4"#"invalid parameters" + params.to_s
      else
        #redirect_to error_page_path
        render text: "invalid parameters" + params.to_s
      end
    end
  end

  def validate_result_parameters
    @refact && @refoper && @status
  end

  def ipn
    render text: params.except(:controller, :action)
  end

  def valid_transaction
    if @request_type.post?
      OmLog.create(log_rl: %Q[_identify=3155832361,_password=#{Digest::MD5.hexdigest('3155832361' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '44680')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')} --- {"_refact": "#{@refact}", "_prix": "#{@mtnt}", "_nooper": "#{@refoper}" }])

      request = Typhoeus::Request.new(
        "http://novaplus.ci/novapay/paycheck.awp", 
        method: :post, 
        body: %Q[{"_refact": "#{@refact}", "_prix": "#{@mtnt}", "_nooper": "#{@refoper}" }], 
        headers: {
          'QUERY-STRING' => %Q[_identify=8150851951,_password=#{Digest::MD5.hexdigest('8150851951' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '32785')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')}]
        }, 
        followlocation: true, 
        method: :get, 
        ssl_verifypeer: false, 
        ssl_verifyhost: 0
      )
      @result = nil
      request.on_complete do |response|
        if response.success?
          @result = response.body.strip
          OmLog.create(log_rl: %Q[https://novaplus.ci/NOVAPAY_WEB/FR/paycheck.awp -- #{@result} --  {"_refact": "#{@refact}", "_prix": "#{@mtnt}", "_nooper": "#{@refoper}" }]) rescue nil
        else
          OmLog.create(log_rl: "Paramètres de vérification de paiement: code " + response.code.to_s + " body " + (response.body.to_s rescue ''))
        end
      end
      request.run

      OmLog.create(log_rl: "Paramètres de vérification de paiement: " + @result.to_s)
    end
    !@result.blank?
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
      basket.update_attributes(notified_to_back_office: true)
    end
  end

  def cashout
    @cashout_account_number = params[:cashout_account_number]
    @transaction_id = params[:_refact]

    @basket = Novapay.find_by_number(@transaction_id)

    if @cashout_account_number.blank?
      @error = true
      @error_messages = ["Veuillez entrer le compte à recharger"]
      initialize_customer_view("77e26b3cbd", "ceiled_transaction_amount", "ceiled_shipping_fee")
      get_service_logo(session[:service].token)
      @basket = Novapay.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

      render :index
    else
      if @basket
        # Cashout mobile money
        operation_token = '98414bba'
        mobile_money_token = 'ffce3241'

        unload_request = "#{Parameter.first.gateway_wallet_url}/api/88bc43ed59e5207c68e864564/mobile_money/cashout/Nsia/#{operation_token}/#{mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.paymoney_password}/#{@basket.original_transaction_amount}/#{(@basket.fees / @basket.rate).ceil.round(2)}"

        unload_response = (RestClient.get(unload_request) rescue "")
        if unload_response.include?('|') || unload_response.blank?
          @status_id = '0'
          # Update in available_wallet the number of failed_transactions
          update_number_of_failed_transactions
          @basket.update_attributes(
            payment_status: false, 
            cashout: true, 
            cashout_completed: false, 
            paymoney_reload_request: unload_request, 
            paymoney_reload_response: unload_response, 
            paymoney_transaction_id: unload_response, 
            cashout_account_number: @cashout_account_number
          )
        else
          @status_id = '5'
          # Update in available_wallet the number of successful_transactions
          #update_number_of_succeed_transactions
          @basket.update_attributes(
            payment_status: true, 
            cashout: true, 
            cashout_completed: true, 
            paymoney_reload_request: unload_request, 
            paymoney_reload_response: unload_response, 
            cashout_account_number: @cashout_account_number
          )
        end

        # Saves the transaction on the front office
        save_cashout_log
        # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=biao&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        redirect_to notification_url(@basket, true, @@wallet_name)
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

      if fee_type
	      @shipping = ((fee_type.fees.where("min_value <= #{session[:trs_amount].to_f} AND max_value >= #{session[:trs_amount].to_f}").first.fee_value) * @rate).ceil.round(2)
	    end
	  end
  end

  # Saves the transaction on the front office
  def save_cashout_log
    log_request = "#{Parameter.first.front_office_url}/api/856332ed59e5207c68e864564/cashout/log/novapay?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}&cashout_account_number=#{@cashout_account_number}&fee=#{@basket.fees}"
    log_response = (RestClient.get(log_request) rescue "")

    @basket.update_attributes(
      cashout_notified_to_front_office: (log_response == '1' ? true : false), 
      cashout_notification_request: log_request, 
      cashout_notification_response: log_response
    )
  end

  # Returns 0 or 1 depending on the status of the transaction
  def transaction_acknowledgement
    generic_transaction_acknowledgement(Novapay, params[:transaction_id])
  end

  def generic_ipn_notification(basket)
    @service = Service.find_by_id(basket.service_id)
    @request = Typhoeus::Request.new(
      "#{@service.url_to_ipn}" + "?" + notification_parameters(@basket, @@wallet_name), 
      followlocation: true, 
      method: :post
    )
    # wallet=05ccd7ba3d
    @request.run
    @response = @request.response
    basket.update_attributes(notified_to_ecommerce: true) if @response.code.to_s == "200"
  end
end
