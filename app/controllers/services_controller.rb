require 'json'

class ServicesController < ApplicationController

  def index
    @services = Service.order("name ASC")
    @duke = JSON.parse @services.to_json
    render text: @duke.first["code"]
  end

  def create
    @status = ""
    if params[:authentication_token].eql?("7a57b200d5be13837de15874300b16ee")
      @code = params[:code]
      @name = params[:name]
      @sales_area = params[:sales_area]
      @comment = params[:comment]
      @url_on_success = params[:url_on_success]
      @url_to_ipn = params[:url_to_ipn]
      @url_on_error = params[:url_on_error]
      @url_on_session_expired = params[:url_on_session_expired]
      @url_on_hold_success = params[:url_on_hold_success]
      @url_on_hold_error = params[:url_on_hold_error]
      @url_on_hold_listener = params[:url_on_hold_listener]
      @url_on_basket_already_paid = params[:url_on_basket_already_paid]
      Service.create(code: @code, name: @name, sales_area: @sales_area, comment: @comment, url_on_success: @url_on_success, url_to_ipn: @url_to_ipn, url_on_error: @url_on_error, url_on_session_expired: @url_on_session_expired, url_on_hold_success: @url_on_hold_success, url_on_hold_error: @url_on_hold_error, url_on_hold_listener: @url_on_hold_listener, url_on_basket_already_paid: @url_on_basket_already_paid)
      @status = "f26e0312bd863867f4f1e6b83483644b"
    else
      @status = "bad request"
    end
    render text: @status
  end

  def update
    @status = ""
    if params[:authentication_token].eql?("7a57b200d5be13837de15874300b16ee")
      service_token = params[:service_token]
      #@sales_area = params[:sales_area]
      #@comment = params[:comment]
      #@code = params[:code]
      url_on_success = params[:url_on_success]
      url_to_ipn = params[:url_to_ipn]
      url_on_error = params[:url_on_error]
      #@url_on_session_expired = params[:url_on_session_expired]
      #@url_on_hold_success = params[:url_on_hold_success]
      #@url_on_hold_error = params[:url_on_hold_error]
      #@url_on_hold_listener = params[:url_on_hold_listener]
      url_on_basket_already_paid = params[:url_on_basket_already_paid]

      @service = Service.find_by_token(service_token)

      if !@service.blank?
        @service.update_attributes(url_on_success: url_on_success, url_to_ipn: url_to_ipn, url_on_error: url_on_error, url_on_basket_already_paid: url_on_basket_already_paid)
        @status = "f26e0312bd863867f4f1e6b83483644b"
      else
        @status = "blank"
      end
    else
      @status = "bad request"
    end

    render text: @status
  end

  def disable
    @status = ""
    disable_enable(params[:service_id], false, params[:authentication_token])

    render text: @status
  end

  def enable
    @status = ""
    disable_enable(params[:service_id], true, params[:authentication_token])

    render text: @status
  end

  def disable_enable(service_id, status, authentication_token)
    if authentication_token.eql?("7a57b200d5be13837de15874300b16ee")
      @service = Service.find_by_id(service_id)
      if !@service.blank?
        @service.update_column(:published, status)
        @status = "f26e0312bd863867f4f1e6b83483644b"
      else
        @status = "blank"
      end
    else
      @status = "bad request"
    end
    @status
  end

  # Create required fields on the back office for the ecommerce to work
  def qualify
    if params_present?(params)
      if Service.find_by_token(params[:token]).nil?
        @wallets = params[:wallets]
        create_service(params)
      else
        render json: {"status" => "1"}
      end
    else
      render json: {"status" => "0"}
    end
  end

  # Creates service and default associated operation
  def create_service(params)
    @service_token = generate_service_token
    @service = Service.create(code: @service_token, name: params[:name], authentication_token: @service_token, url_on_success: params[:pdt_url], url_on_error: params[:pdt_url], url_to_ipn: params[:ipn_url], token: params[:token], ecommerce_profile_id: (EcommerceProfile.find_by_token(params[:ecommerce_profile_token]).id rescue ''))
    if @service
      create_operation
    else
      render json: {"status" => "2"}
    end
  end

  # Creates default operation
  def create_operation
    @operation_token = generate_operation_token
    @operation = @service.operations.create(code: @operation_token, authentication_token: @operation_token)
    if @operation
      create_available_wallets
    else
      @service.delete
      render json: {"status" => "3"}
    end
  end

  def create_available_wallets
    # wallets structure is like: [["05ccd7ba3d", true], ["b005fd07f0", true], ["936166e255", false], ["e6da96e284", false]]
    wallets = JSON.parse(@wallets) rescue nil
    if wallets
      wallet_creation_failed = wallets_creation_succeed?(wallets)

      # Deletes everything if the creation of even a single wallet failed
      if wallet_creation_failed
        @service.available_wallets.each do |available_wallet|
          available_wallet.delete
        end
        delete_service_and_operation
        render json: {"status" => "5"}
      else
        render json: {"status" => "6", "service_token" => @service_token, "operation_token" => @operation_token}
      end
    else
      delete_service_and_operation
      render json: {"status" => "4"}
    end
  end

  # Enables or disables a wallet for a given service
  def enable_disable
    @service = Service.find_by_token(params[:service_token])

    if @service
      @service.update_attribute(:published, (params[:status] == "true" ? true : false))
      render json: {"status" => "1"}
    else
      render json: {"status" => "0"}
    end
  end

  # Returns true or false depending on the wallets creation status
  def wallets_creation_succeed?(wallets)
    wallet_creation_failed = false
    # Creates available wallets for a given service (Ecommerce)
    wallets.each do |wallet|
      @wallet = Wallet.find_by_authentication_token(wallet[0])
      if @wallet
        @service.available_wallets.create(wallet_id: @wallet.id, published: (wallet[1] == true ? true : false))
      else
        wallet_creation_failed = true
      end
    end

    return wallet_creation_failed
  end

  def params_present?(params)
    if params[:name].blank? || params[:pdt_url].blank? || params[:ipn_url].blank? || params[:order_already_paid].blank? || params[:wallets].blank? || params[:token].blank? || params[:ecommerce_profile_token].blank?
      return false
    else
      return true
    end
  end

  def generate_service_token
    begin
      token = SecureRandom.hex(16)
    end while (Service.all.map{|m| m.authentication_token}).include?(token)

    return token
  end

  def generate_operation_token
    begin
      token = SecureRandom.uuid
    end while (Operation.all.map{|m| m.authentication_token}).include?(token)

    return token
  end

  def delete_service_and_operation
    @service.delete
    @operation.delete
  end

end
