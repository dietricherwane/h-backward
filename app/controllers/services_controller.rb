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
      @service_id = params[:service_id]
      @sales_area = params[:sales_area]
      @comment = params[:comment]
      @code = params[:code]
      @url_on_success = params[:url_on_success]
      @url_to_ipn = params[:url_to_ipn]
      @url_on_error = params[:url_on_error]
      @url_on_session_expired = params[:url_on_session_expired]
      @url_on_hold_success = params[:url_on_hold_success]
      @url_on_hold_error = params[:url_on_hold_error]
      @url_on_hold_listener = params[:url_on_hold_listener]
      @url_on_basket_already_paid = params[:url_on_basket_already_paid]
      
      @service = Service.find_by_id(@service_id)
      
      if !@service.blank?
        @service.update_attributes(code: @code, sales_area: @sales_area, comment: @comment, url_on_success: @url_on_success, url_to_ipn: @url_to_ipn, url_on_error: @url_on_error, url_on_session_expired: @url_on_session_expired, url_on_hold_success: @url_on_hold_success, url_on_hold_error: @url_on_hold_error, url_on_hold_listener: @url_on_hold_listener, url_on_basket_already_paid: @url_on_basket_already_paid)
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
  
end
