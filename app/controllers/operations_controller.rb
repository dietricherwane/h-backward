class OperationsController < ApplicationController

  def create
    @status = ""
    if params[:authentication_token].eql?("7a57b200d5be13837de15874300b16ee")
      @service_id = params[:service_id]
      @service = Service.find_by_id(@service_id)
      
      if @service.blank?
        @status = "bad request" 
      else      
        @service.operations.create(name: params[:name], comment: params[:comment])
        @status = "f26e0312bd863867f4f1e6b83483644b"
      end
    else
      @status = "bad request" 
    end
    render text: @status
  end
  
  def update
    @status = ""
    if params[:authentication_token].eql?("7a57b200d5be13837de15874300b16ee") 
      @operation = Operation.find_by_id(params[:operation_id])
      if @operation.blank?
        @status = "bad request" 
      else      
        @operation.update_attributes(name: params[:name], comment: params[:comment])
        @status = "f26e0312bd863867f4f1e6b83483644b"
      end
    else
      @status = "bad request" 
    end
    render text: @status
  end
  
  def disable
    @status = ""
    disable_enable(params[:operation_id], false, params[:authentication_token])

    render text: @status
  end
  
  def enable
    @status = ""
    disable_enable(params[:operation_id], true, params[:authentication_token])

    render text: @status
  end
  
  def disable_enable(operation_id, status, authentication_token)
    if authentication_token.eql?("7a57b200d5be13837de15874300b16ee")
      @operation = Operation.find_by_id(operation_id)
      if !@operation.blank?
        @operation.update_column(:published, status)
        @status = "f26e0312bd863867f4f1e6b83483644b"
      else
        @status = "bad request"
      end      
    else
      @status = "bad request"
    end
    @status
  end

end
