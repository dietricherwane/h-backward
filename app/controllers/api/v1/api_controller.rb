class Api::V1::ApiController < ActionController::Base
  include Api::V1::Auth
  include Api::V1::Validator
  include Api::V1::Response

  before_action :authenticate, except: :get_auth_token # test

  def get_auth_token
    render text: rebuild_auth_token
  end

  def load_required_fields
    @@wallets_required_filed ||= YAML::load_file(Rails.root.join("config", "api_wallets_required_fields.yml").to_s)
  end

  def generate_transaction_id(len = 8)
    chars_source = %w{ 0 1 2 3 4 5 6 7 8 9}
    code = (0...len).map{ chars_source.to_a[rand(chars_source.size)] }.join
    code
  end

  # Génère l'URL de notification du ecommerce
  def notification_url(basket, successfull, wallet_name)
    url = successfull ? basket.service.url_on_success : basket.service.url_on_error
    parameters = notification_parameters(basket, wallet_name)
    url += "?" + parameters
  end

  def notification_parameters(basket, wallet_name)
    params = {
      transaction_id:                 basket.transaction_id,
      order_id:                       basket.number,
      status_id:                      @status_id,
      wallet:                         wallet_name,
      transaction_amount:             basket.original_transaction_amount,
      currency:                       basket.currency.code,
      paid_transaction_amount:        basket.paid_transaction_amount,
      paid_currency:                  Currency.find_by_id(basket.paid_currency_id).code,
      change_rate:                    basket.rate,
      id:                             basket.login_id,
      conflictual_transaction_amount: basket.conflictual_transaction_amount,
      conflictual_currency:           basket.conflictual_currency
    }
    params.to_query
  end

  def get_change_rate(from, to)
    rate = 0
    if from == to
      rate = 1
    else
      rate = ActiveRecord::Base.connection.execute("SELECT * FROM currencies_matches WHERE first_code = '#{from}' AND second_code = '#{to}'").first["rate"].to_f
    end
  end

  def ceiled_shipping_fee
    get_shipping_fee.ceil
  end

  def unceiled_shipping_fee
    get_shipping_fee
  end

  # Récupère les frais de transaction en fonction du wallet
  def get_shipping_fee
    @fee = 0
    if @service.fee
      @fee = ((@transaction_amount.to_f * (@service.fee || 0)) / 100).round(2)
    else
      @fee = @wallet.fee
      if @wallet && @wallet.percentage
        @fee = (((@transaction_amount).to_f * @wallet.fee) / 100).round(2)
      end
    end
  end

  def set_all_necessary_objects
    get_service_with_operation
    get_wallet_with_currency
    get_service_currency
  end

  def get_service_with_operation
    @operation = Operation.where(authentication_token: params[:operation_token]).first
    @service = @operation.service
    raise if @service.nil? or @operation.nil?
  rescue
    response = ErrorResponse::format_response('11', "Le token de service/operation n'est pas valide.")
    render json: response, status: :unprocessable_entity
  end

  def get_service_currency
    @service_currency = Currency.where("code = '#{params[:currency_code].upcase}' AND published IS TRUE").first
  end

  def get_wallet_with_currency
    @wallet_alias = params[:payment_method].downcase
    @wallet = Wallet.find_by(alias: @wallet_alias)
    @wallet_currency = @wallet.currency
  end

  # def get_paymoney_account_token
  #   response = Wallets::Paymoney.get_account_token(params[:account_number])
  #   response.body.to_s if response.code == 200
  # end

  # Use authentication_token to update wallet used
  def update_wallet_used(basket, authentication_token)
    @available_wallet = basket.service.available_wallets.where(wallet_id: Wallet.find_by_authentication_token(authentication_token).id).first rescue nil
    @available_wallet.update_attribute(:wallet_used, true) rescue nil
  end

  # Update in available_wallet the number of successful transactions
  def update_number_of_succeed_transactions
    @available_wallet.update_attribute(:succeed_transactions, (@available_wallet.succeed_transactions.to_i + 1)) rescue nil
  end

  # Update in available_wallet the number of failed transactions
  def update_number_of_failed_transactions
    @available_wallet.update_attribute(:failed_transactions, (@available_wallet.failed_transactions.to_i + 1)) rescue nil
  end
end
