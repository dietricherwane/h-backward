class UbaController < ApplicationController
  @@wallet_name = 'uba'
  @@second_origin_url = Parameter.first.second_origin_url
  before_action :session_authenticated?, :except => [:guard, :cashout]

  # Set transaction amount for GUCE requests
  before_action :set_guce_transaction_amount, :only => :index

  #@@bill_request = "http://27.34.246.91:8080/Guce/uba/billrequest"
  @@bill_request = "http://27.34.246.91:8080/Guce/uba/billrequest"

  #layout "uba"
  layout :select_layout

  def select_layout
    session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559' ? "guce" : "uba"
  end

  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end

  def index
    initialize_customer_view("0e6cc1e046", "ceiled_transaction_amount", "ceiled_shipping_fee")
    get_service_logo(session[:service].token)

    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = Uba.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

    if (@service.authentication_token rescue nil) == "62c0e7c8189e0737cb036999d3994719"
      session[:trs_amount] = session[:trs_amount].to_f.ceil - @shipping
      @transaction_amount = session[:trs_amount].to_f.ceil - @shipping
    end

    set_cashout_fee

    if @basket.blank?
      @basket = Uba.create(
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

  def validate_transaction
    @firstname = params[:firstname]
    @lastname = params[:lastname]
    @msisdn = params[:msisdn]
    @email = params[:email]
    @error_messages = []

    validate_user_params

    @basket = Uba.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'").first rescue nil

    if @error_messages.blank?
      request = Typhoeus::Request.new(
        @@bill_request, 
        method: :post, 
        body: {
          userName: 'ngser', 
          password: 'ngser', 
          currency: 'XOF', 
          referenceInvoice: @basket.transaction_id, 
          amount: @basket.paid_transaction_amount, 
          serviceFees: @basket.fees, 
          operatorId: '411cd', 
          guceTransactionId: @basket.transaction_id, 
          channelId: '01', 
          firstname: @firstname, 
          lastname: @lastname, 
          email: @email, 
          phone: @msisdn
        }, 
        followlocation: true
      )
      request.run
      response = request.response

      #render text: "response_code: " + response.code.to_s + " " + str

    else
      @error = true
      params[:firstname] = @firstname
      params[:lastname] = @lastname
      params[:msisdn] = @msisdn
      params[:email] = @email
      initialize_customer_view("0e6cc1e046", "ceiled_transaction_amount", "ceiled_shipping_fee")
      get_service_logo(session[:service].token)
    end

    if @error_messages.blank?
     render text: response.body
    else
      render :index
    end
  end

  def cashout
    @cashout_account_number = params[:cashout_account_number]
    @transaction_id = params[:transaction_id]

    @basket = Uba.find_by_transaction_id(@transaction_id)

    if @cashout_account_number.blank?
      @error = true
      @error_messages = ["Veuillez entrer le compte à recharger"]
      initialize_customer_view("0e6cc1e046", "ceiled_transaction_amount", "ceiled_shipping_fee")
      get_service_logo(session[:service].token)
      @basket = Uba.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")

      render :index
    else
      if @basket
        # Cashout mobile money
        operation_token = 'cb77b491'
        mobile_money_token = '8ed6ab4a'

        unload_request = "#{Parameter.first.gateway_wallet_url}/api/88bc43ed59e5207c68e864564/mobile_money/cashout/Uba/#{operation_token}/#{mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.paymoney_password}/#{@basket.original_transaction_amount}/#{(@basket.fees / @basket.rate).ceil.round(2)}"

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

        # redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&wallet=uba&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        redirect_to notification_url(@basket, successfull, @@wallet_name)
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
    log_request = "#{Parameter.first.front_office_url}/api/856332ed59e5207c68e864564/cashout/log/uba?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=#{@status_id}&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}&cashout_account_number=#{@cashout_account_number}&fee=#{@basket.fees}"
    log_response = (RestClient.get(log_request) rescue "")

    @basket.update_attributes(
      cashout_notified_to_front_office: (log_response == '1' ? true : false), 
      cashout_notification_request: log_request, 
      cashout_notification_response: log_response
    )
  end

  def validate_user_params
    if @firstname.blank?
      @error_messages << "Le nom n'est pas valide."
    end
    if @lastname.blank?
      @error_messages << "Le prénom n'est pas valide."
    end
    if !valid_email?(@email)
      @error_messages << "L'email n'est pas valide."
    end
    if not_a_number?(@msisdn) || (@msisdn.length != 8 && @msisdn.length != 11)
      @error_messages << "Le numéro de téléphone n'est pas valide."
    end
  end

  def transaction_acknowledgement
    OmLog.create(log_rl: 'UBA -- ' + params.to_s) rescue nil
    render text: params
  end
end