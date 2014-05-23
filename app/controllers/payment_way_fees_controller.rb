class PaymentWayFeesController < ApplicationController
  
  def create
    @status = ""
    if params[:authentication_token].eql?("7a57b200d5be13837de15874300b16ee")
      @name = params[:name]
      @percentage = params[:percentage]
      @fee = params[:fee]
      @percentage.eql?("true") ? @percentage = true : @percentage = false
            
      PaymentWayFee.create(name: @name, percentage: @percentage, fee: @fee)
      @status = "f26e0312bd863867f4f1e6b83483644b"
    else
      @status = "bad request" 
    end
    render text: @status 
  end
  
  def update
    @status = ""
    if params[:authentication_token].eql?("7a57b200d5be13837de15874300b16ee")
      @id = params[:id]
      @percentage = params[:percentage]
      @fee = params[:fee]
      @percentage.eql?("true") ? @percentage = true : @percentage = false

      @payment_way_fee = PaymentWayFee.find_by_id(@id)
      
      if !@payment_way_fee.blank?
        @payment_way_fee.update_attributes(percentage: @percentage, fee: @fee)
        @status = "f26e0312bd863867f4f1e6b83483644b"
      else
        @status = "blank" 
      end
    else
      @status = "bad request" 
    end
    
    render text: @status
  end
  
end
