class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  # Initialise la variable de session contenant les informations sur la transaction
  def get_service_by_token(currency, service_token, operation_token, order, transaction_amount)
    # si la devise envoyee n'existe pas, on renvoie la page d'erreur
    currency_exists?(currency)
    session[:currency] = @currency.first
    @service = Service.where("authentication_token = '#{service_token}' AND published IS NOT FALSE")
    unless @service.blank?
      @service = @service.first
      @operation = Operation.where("authentication_token = '#{operation_token}' AND service_id = #{@service.id} AND published IS NOT FALSE")
      unless @operation.blank?
        @operation = @operation.first
        unless not_a_number?(transaction_amount)
          session[:service] = Service.find_by_authentication_token(service_token)
          session[:operation] = Operation.find_by_authentication_token(operation_token)
          session[:trs_amount] = transaction_amount.to_f.round(2)
          session[:basket] = {"basket_number" => "#{order}", "transaction_amount" => "#{transaction_amount.to_f.round(2)}"}
        end
      end
    end
  end

  # Verifie que la devise existe dans la base de donnees
  def currency_exists?(currency)
    @currency = Currency.where("code = '#{currency.upcase}' AND published IS TRUE")
    if @currency.blank?
      redirect_to error_page_path
    end
  end

  # Initialise la variable de session contenant les informations sur la transaction
  def get_service(service_id, operation_id, basket_number, transaction_amount)
    @service = Service.find_by_code(service_id)
    unless @service.blank?
      @operation = @service.operations.find_by_id(operation_id)
      unless @operation.blank?
        unless not_a_number?(transaction_amount)
          session[:service] = @service
          session[:operation] = @operation
          session[:basket] = {"basket_number" => "#{basket_number}", "transaction_amount" => "#{transaction_amount.to_f}"}
        end
      end
    end
  end

  def get_change_rate(from, to)
    @from = from
    @to = to
    @rate = 0
    if @from ==@to
      @rate = 1
    else
      @rate = ActiveRecord::Base.connection.execute("SELECT * FROM currencies_matches WHERE first_code = '#{@from}' AND second_code = '#{@to}'").first["rate"].to_f
    end
    @rate
  end

  # S'assure que la variable de session existe
  def session_exists?
    if (session[:service].blank? or session[:operation].blank? or session[:basket].blank?)
      #redirect_to session[:service].url_on_session_expired
      redirect_to error_page_path
    end
  end

  def session_authenticated?
    if session[:b83eff1c1b3fdbb26153075044297e91].blank?
      redirect_to error_page_path
    end
  end

  # Vérifie que la variable de session existe, que l'opération demandée existe, que le montant de la transaction est numérique
  def filter_connections
    if session[:service].blank? or session[:operation].blank? or session[:basket].blank? or not_a_number?(session[:basket]["transaction_amount"])
      #redirect_to session[:service].url_on_error
      redirect_to error_page_path
    end
  end

  # Vérifie que le panier n'a pas déjà été payé
  def basket_already_paid?(basket_number)
    if session[:service].blank?
      #redirect_to session[:service].url_on_session_expired
      redirect_to error_page_path
    else
      @basket = session[:service].baskets.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @paypal_basket = session[:service].paypal_baskets.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @orange_money_ci_basket = session[:service].orange_money_ci_baskets.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @qash_basket = session[:service].qash_baskets.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @delayed_payment = session[:service].delayed_payments.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      #session[:service_id] = @service.id
      if ((!@basket.blank? and @basket.first.payment_status.eql?(true)) or (!@paypal_basket.blank? and @paypal_basket.first.payment_status.eql?(true)) or (!@delayed_payment.blank? and @delayed_payment.first.payment_status.eql?(true)) or (!@orange_money_ci_basket.blank? and @orange_money_ci_basket.first.payment_status.eql?(true)) or (!@qash_basket.blank? and @qash_basket.first.payment_status.eql?(true)))
        redirect_to "#{session[:service].url_on_basket_already_paid}?status_id=2"
        #redirect_to error_page_path
      end
    end
  end

  def generate_url(url, params = {})
    uri = URI(url)
    uri.query = params.to_query
    uri.to_s
  end

  def run_typhoeus_request(request, code_on_success)
    @error_messages = []
    request.on_complete do |response|
      if response.success?
        eval(code_on_success)
      elsif response.timed_out?
        @error_messages << "Délai d'attente de la demande dépassé. Veuillez contacter l'administrateur."
        @error = true
      elsif response.code == 0
        @error_messages << "L'URL demandé n'existe pas. Veuillez contacter l'administrateur."
        @error = true
      else
        @error_messages << "Une erreur s'est produite. Veuillez contacter l'administrateur"
        @error = true
      end
    end
    hydra = Typhoeus::Hydra.hydra
	  hydra.queue(request)
	  hydra.run
  end



  def authenticate_incoming_request(operation_id, basket_number, transaction_amount)
    @request = Typhoeus::Request.new(session[:service]["url_to_authenticate_incoming_request"], method: :post, params: {operation_id: "#{operation_id}", basket_number: "#{basket_number}", transaction_amount: "#{transaction_amount}"})
    @request.run
    @response = @request.response
    if(params[:status] != session[:service]["authentication_token"])
      redirect_to error_page_path
    end
  end

  def not_a_number?(n)
  	n.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? true : false
  end

  def name_correct?(name)
    if(name.blank? or name.length == 1)
      false
    else
      true
    end
  end

  def valid_email?(email)
    /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i.match(email).blank? ? false : true
  end

  # Manages transaction acknowledgements fo all wallets
  def generic_transaction_acknowledgement(my_model, transaction_id)
    status = "0"
    order = my_model.find_by_transaction_id(transaction_id)
    if order
      if order.payment_status == true
        status = "1"
      end
    end
    render :text => status
  end

  # Initialize mandatory variables before displaying the payment validation form to the user
  # récupération du wallet, de la monnaie utilisée par le wallet, du taux de change entre la monnaie envoyée par le ecommerce et celle du wallet, conversion du montant envoyé par le ecommerce en celui supporté par le wallet et affichage des frais de transfert
  def initialize_customer_view(wallet_authentication_token, set_transaction_amount, set_shipping_fee)
    @wallet = Wallet.find_by_authentication_token(wallet_authentication_token)
    @wallet_currency = @wallet.currency
    @rate = get_change_rate(session[:currency].code, @wallet_currency.code)
    send(set_transaction_amount)
    @shipping = send(set_shipping_fee)
  end

  def ceiled_transaction_amount
    session[:basket]["transaction_amount"] = (session[:trs_amount].to_f.ceil * @rate).ceil
  end

  def unceiled_transaction_amount
    session[:basket]["transaction_amount"] = (session[:trs_amount] * @rate).round(2)
  end

  def ceiled_shipping_fee
    return get_shipping_fee.ceil
  end

  def unceiled_shipping_fee
    return get_shipping_fee
  end

  # Récupère les frais de transaction en fonction du wallet
  def get_shipping_fee
    @fee = 0

    if @wallet
      if(@wallet.percentage)
        @fee = (((session[:basket]["transaction_amount"]).to_f * @wallet.fee) / 100).round(2)
      else
        @fee = @wallet.fee
      end
    end
    return @fee
  end

end
