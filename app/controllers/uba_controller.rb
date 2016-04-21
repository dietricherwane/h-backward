class UbaController < ApplicationController
  @@second_origin_url = Parameter.first.second_origin_url
  before_action :except => :guard do |s| s.session_authenticated? end

  # Set transaction amount for GUCE requests
  before_action :only => :index do |o| o.guce_request? end

  #@@bill_request = "http://27.34.246.91:8080/Guce/uba/billrequest"
  @@bill_request = "http://27.34.246.91:8080/Guce/uba/billrequest_1"

  #layout "uba"
  layout :select_layout

  def select_layout
    if session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559'
      return "guce"
    else
      return "uba"
    end
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

    if @basket.blank?
      @basket = Uba.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :original_transaction_amount => session[:trs_amount], :transaction_amount => session[:trs_amount].to_f.ceil, :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, transaction_id: Digest::SHA1.hexdigest([DateTime.now.iso8601(6), rand].join), :fees => @shipping, :rate => @rate, :login_id => session[:login_id])
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount].to_f.ceil, :original_transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate, :login_id => session[:login_id])
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
      request = Typhoeus::Request.new(@@bill_request, method: :post, body: {userName: 'ngser', password: 'ngser', currency: 'XOF', referenceInvoice: 'XOF', amount: @basket.paid_transaction_amount, serviceFees: @basket.fees, operatorId: '411cd', guceTransactionId: @basket.transaction_id, channelId: '01', firstname: @firstname, lastname: @lastname, email: @email, phone: @msisdn}, followlocation: true)

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

end
