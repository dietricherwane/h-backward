class Api::V1::PaymentsController < Api::V1::ApiController
  before_action only: :process_payment do
    validate(params)
  end
  before_action :abort_if_already_paid, only: :process_payment
  before_action :set_all_necessary_objects, only: :process_payment

  def check_payment_status
    @basket = get_model.find_by(transaction_id: params[:transaction_id])
    begin
      raise if @basket.nil?
      status = :ok
      if @basket.payment_status == true or @basket.process_online_response_code == "01"
        response = SuccessResponse::format_response(params[:payment_method], @basket)
      else
        response = PendingResponse::format_response(params[:payment_method], @basket) if @basket.process_online_response_code == "1000"
        response = FailResponse::format_response('03', 'La transaction a échoué.') if @basket.payment_status != true
      end
    rescue
      status = :not_found
      response = FailResponse::format_response('06', "Cette transaction n'existe pas.")
    end

    render json: response, except: :http_status, status: status
    # TODO Handle status return
    # render json: Api::V1::SuccessResponse
  end

  def process_payment
    service_id = @service.id
    operation_id = @operation.id
    # payment_method = params[:payment_method]
    transaction_number = params[:transaction_number]
    transaction_amount = params[:transaction_amount]
    # transaction_currency = params[:transaction_currency]
    # paymoney_account_number = params[:account_number]
    # wallet = params[:payment_method].downcase

    # auth_token = params[:auth_token]

    transaction_id = generate_transaction_id
    @basket = get_model.find_or_initialize_by(number: transaction_number)
    @basket.update_attributes(
      number: transaction_number,
      service_id: service_id,
      operation_id: operation_id,
      original_transaction_amount: transaction_amount,
      transaction_amount: transaction_amount.to_f.ceil,
      currency_id: @service_currency.id,
      paid_transaction_amount: transaction_amount,
      paid_currency_id: @wallet_currency.id,
      transaction_id: transaction_id,
      fees: ceiled_shipping_fee,
      rate: get_change_rate(@service_currency.code, @wallet_currency.code),
      # login_id: session[:login_id],
      # paymoney_account_number: paymoney_account_number,
      # paymoney_account_token: get_paymoney_account_token
    )

    send("process_#{@wallet_alias}_payment")
  end

  def process_paymoney_payment
    params[:Frais] = @basket.fees
    @password = params[:password]

    check_operation_paymoney_token

    get_customer_paymoney_token

    @basket.update_attributes(
      paymoney_account_number: params[:account_number],
      paymoney_account_token: @customer_paymoney_token
    )

    unload_response = Wallets::Paymoney.unload(
      service_profile_token: @basket.service.ecommerce_profile.token,
      operation_paymoney_token: @operation_paymoney_token,
      customer_paymoney_token: @basket.paymoney_account_token,
      transaction_amount: @basket.transaction_amount,
      fees: @basket.fees,
      transaction_id: @basket.number,
      password: @password
    )

    status = unload_response.body
    Log.create(
      description: "Paymoney sale",
      sent_request: unload_response.request.path.to_s,
      sent_response: status,
      paymoney_account_number: @basket.paymoney_account_number,
      paymoney_token_request: @token_response.request.path.to_s,
      paymoney_token_response: @customer_paymoney_token
    )

    if status.to_s.strip == "good"
      @basket.update_attributes(
        paid_transaction_amount: @basket.transaction_amount,
        paid_currency_id: @wallet_currency.id,
        rate: @rate,
        payment_status: true
      )
      # communication with back office
      @rate = get_change_rate(@wallet_currency.code, "EUR")
      @basket.update_attributes(compensation_rate: @rate)
      @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
      @fees_for_compensation = (@basket.fees * @rate).round(2)
      # Use Paymoney authentication_token
      update_wallet_used(@basket, "05ccd7ba3d")
      # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
      @basket.update_attributes(notified_to_back_office: false, payment_status: true)

      response = Api::V1::SuccessResponse::format_response(params[:payment_method], @basket)
    elsif status.to_s.strip == "error, montant insuffisant"
      response = Api::V1::FailResponse::format_response('09', "Le solde du compte est insuffisant.")
    else
      response = Api::V1::FailResponse::format_response('08', "Le mot de passe n'est pas valide.")
    end
    render json: response, status: :ok
  end

  # Validates existence of operation paymoney token
  def check_operation_paymoney_token
    @operation_paymoney_token = @basket.operation.paymoney_token
    raise "Cette operation n'a pas pas de token PayMoney." if @operation_paymoney_token.nil?
  rescue Exception => e
    response = Api::V1::Response::ErrorResponse::format_response('12', e.message)
    render json: response, status: :unprocessable_entity
  end

  # Retrieves customer paymoney token
  def get_customer_paymoney_token
    @token_response = Wallets::Paymoney.get_account_token(@basket.paymoney_account_number)
    @customer_paymoney_token = token_response.body if response.code == 200
    raise "Le numéro de compte PayMoney n'est pas valide." if @token.nil?
  rescue Exception => e
    response = Api::V1::Response::FailResponse::format_response('07', e.message)
    render json: response, status: :unprocessable_entity
  end

  def process_mtnmomo_payment
    @mtn_msisdn = params[:phone_number]
    # byebug
    @response = Wallets::Mtnmomo.unload(
      msisdn: @mtn_msisdn,
      processing_number: @basket.transaction_id,
      due_amount: @basket.transaction_amount + @basket.fees
    )
    @basket.update_attributes(
      sent_request: @response.request.options[:body].to_s,
      phone_number: @mtn_msisdn,
      type_token: 'WEB'
    )
    # @status_code = nil
    update_wallet_used(@basket, "73007113fe")
    response = {}
    status = :ok
    if @response.code == 200
      # Update basket based on wallet return
      # Redirect to ecommerce with relevant status
      response = handle_mtnmomo_return
      # send("handle_#{@wallet_alias}_return")
    else
      # Update basket based on wallet return
      # Redirect to ecommerce with relevant status
      response = handle_failed_transaction
    end
    render json: response, status: status
  end

  def handle_mtnmomo_return
    response_code = Nokogiri.XML(@response.body)
    return_array = response_code.xpath('//return')
    response_code = return_array[3].to_s
    response_code = Nokogiri.XML(response_code)

    @response_code = response_code.xpath('//value').first.text
    if @response_code.to_s.strip == '1000'
      # Handle succed transaction
      handle_succeed_transaction
    else
      # Handle failed transaction
      handle_failed_transaction
    end
  end

  def handle_succeed_transaction
    update_number_of_succeed_transactions
    @basket.update_attributes(
      process_online_response_code: @response_code,
      process_online_response_message: @response.body
    )
    PendingResponse::format_response(params[:payment_method], @basket)
    # render json: { status: 'pending', message: "En attente de la validation deu cient." }
    # TODO Handle success with Api::V1::SuccessResponse
  end

  def handle_failed_transaction
    update_number_of_failed_transactions
    @basket.update_attributes(
      process_online_response_code: @response_code,
      process_online_response_message: @response.body,
      payment_status: false
    )
    FailResponse::format_response('03', 'La transaction a échoué.')
    # render json: { status: 'fail', message: "La transaction a échoué." }
    # TODO Render an error in json format with Api::V1::ErrorResponse
  end

  def get_model
    file = Rails.root.join("config", "api_wallet_model.yml")
    @@model ||= YAML.load_file(file)[params[:payment_method]].constantize
  end

  def abort_if_already_paid
    raise if transaction_already_paid?
  rescue
    info = 'Cette transaction a déjà été payé.'
    render json: SuccessResponse::format_response(params[:payment_method], transaction || transaction2, info)
  end

  def transaction_already_paid?
    transaction = MtnCi.where(number: params[:transaction_number], payment_status: true).first
    transaction2 = Basket.where(number: params[:transaction_number], payment_status: true).first

    transaction || transaction2
  end

  # def handle_paymoney_return
  #   if @status.to_s.strip == "good"
  #   else
  #   end
  # end

  # def get_wallet_class
  #   klass = 'Wallets::' + 'mtnmomo'.capitalize
  #   klass.constantize
  # end

  # def withdraw
  #
  # end
  #
  # def cashin
  #
  # end

  # def payment_params
  #   params.fetch()
  # end
end
