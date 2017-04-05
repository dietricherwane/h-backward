module Api::V1::Validator
    API_DEFAULT_PARAMS = %W[
      operation_token
      transaction_date
    ].freeze

    API_PAYMENT_PARAMS = %W[
      payment_method
      transaction_number
      transaction_amount
      currency_code
    ].freeze

    attr_reader :messages

    @messages = {}

    def validate(params)
      @messages = {
        fail: [],
        error: []
      }
      payment_method = params[:payment_method]

      validate_existence_of_payment_method(payment_method)
      validate_presence_of_params(payment_method)
    end

    # Sets errors messages if any encountered
    def validate_presence_of_params(payment_method)
      @messages[:fail] = []
      required_params = API_DEFAULT_PARAMS # if payment_method.nil?
      # byebug
      required_params += API_PAYMENT_PARAMS.+ mtnmomo_params if payment_method == 'mtnmomo'
      required_params += API_PAYMENT_PARAMS.+ paymoney_params if payment_method == 'paymoney'
      required_params.each do |param|
        # byebug
        if params[param.to_s].nil?
          @messages[:fail] << "Le champ '#{param.to_s}' est requis."
        end
      end
      # byebug
      raise unless @messages[:fail].empty?
    rescue
      response = Api::V1::Response::FailResponse::format_response('04', @messages[:fail])
      render json: response, status: :unprocessable_entity
    end

    # Validates payment method
    def validate_existence_of_payment_method(payment_method)
      @messages[:error] = []
      wallet_list = load_file 'api_wallets_required_fields.yml'
      unless wallet_list.has_key? payment_method
        @messages[:error] << "Ce moyen de paiement n'est pas reconnu."
      end
      raise unless @messages[:error].empty?
    rescue
      response = Api::V1::Response::ErrorResponse::format_response('13', @messages[:error])
      render json: response, status: :unprocessable_entity
    end

    private

    # Retrieves wallet specific required field from config file
    def mtnmomo_params
      params_list = load_file 'api_wallets_required_fields.yml'
      params_list['mtnmomo'].collect { |param| param['name'] }
    end

    # Retrieves wallet specific required field from config file
    def paymoney_params
      params_list = load_file 'api_wallets_required_fields.yml'
      params_list['paymoney'].collect { |param| param['name'] }
    end

    # Loads config file
    def load_file(filename)
      @wallet_with_fields ||= YAML::load_file(Rails.root.join('config', filename).to_s)
    end
end
