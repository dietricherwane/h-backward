class DelayedPaymentsController < ApplicationController
  #@@url = "http://localhost:8080"
  @@url = "http://41.189.40.193:8080"
  # Only for guard action, we check if service_id exists and initialize a session variable containing transaction_data
  before_action :only => :guard do |s| s.get_service(params[:service_id], params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Only for guard action, we check if the session varable is initialized, if the operation_id is initialized and if transaction_amount is a number
  before_action :only => :guard do |o| o.filter_connections end
  #before_action :only => :guard do |r| r.authenticate_incoming_request(params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Vérifie que le panier n'a pas déjà été payé via paypal
  before_action :only => :guard do |s| s.basket_already_paid?(params[:basket_number]) end
  # Vérifie pour toutes les actions que la variable de session existe
  before_action :session_exists?
  
  layout false
  
  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end  
  
  # Efface les parmètres du corps de la requête et affiche un friendly url dans le navigateur du client
  def index
    @url = "#{session[:service]['url_on_hold_error']}?order_id=#{session[:service]["operation_id"]}"
    session[:service]["transaction_amount"] = (session[:service]["transaction_amount"].to_f).round(2).to_s
    @shipping = get_shipping_fee("DelayedPayment")
    @basket = DelayedPayment.where("number = '#{session[:service]["basket_number"]}' AND service_id = #{session[:service_id]} AND operation_id = #{session[:service]["operation_id"]}")
    if @basket.blank?      
      @request = Typhoeus::Request.new("#{@@url}/GATEWAY/rest/WS/#{session[:service]['operation_id']}/#{session[:service]['basket_number']}/#{session[:service]['basket_number']}/#{session[:service]["transaction_amount"].to_f + @shipping.to_f}/#{@shipping.to_f}/4", followlocation: true)
      @internal_com_request = "@response = Nokogiri.XML(request.response.body)
      @response.xpath('//status').each do |link|
      @status = link.content
      end
      "
      #session[:service]['transaction_status'] = @status
      
      run_typhoeus_request(@request, @internal_com_request)
      
      if @status.to_s.strip == "1"
        DelayedPayment.create(:number => session[:service]["basket_number"], :service_id => session[:service_id], :operation_id => session[:service]["operation_id"], :transaction_amount => (session[:service]["transaction_amount"].to_f + @shipping), :notified_to_back_office => true, transaction_id: Time.now.strftime("%Y%m%d%H%M%S%L"))
        @url = "#{session[:service]['url_on_hold_success']}?order_id=#{session[:service]["operation_id"]}"
      end
    end           
    #redirect_to @url
    render text: "ok"
  end
  
  def delayed_payment_listener
    @service_id = params[:service_id]
    @operation_id = params[:operation_id]
    @basket_number = params[:basket_number]
    @transaction_amount = params[:transaction_amount]
    @status = "0"
    
    unless @service_id.blank? or @operation_id.blank? or @basket_number.blank? or @transaction_amount.blank?
      @basket = DelayedPayment.where("number = '#{@basket_number}' AND service_id = #{@service_id} AND operation_id = #{@operation_id} AND transaction_amount = #{@transaction_amount}")
      unless @basket.blank?
        @basket_to_update = DelayedPayment.find_by_id(@basket.first.id)
        @basket_to_update.update_attributes(payment_status: true)
        @status = "1"
        
        #url1 on success and url2 on success
        @request = Typhoeus::Request.new("#{@@url}/#{@basket_to_update.basket_number}/#{@basket_to_update.transaction_amount}", followlocation: true)
        @internal_com_request = "@response = request.response.body"        
        run_typhoeus_request(@request, @internal_com_request)
        #session[:service]['transaction_status'] = @status        
        run_typhoeus_request(@request, @internal_com_request)
      end
    end
    render :template => "delayed_payments/delayed_payment_listener.xml.builder", :layout => false
  end  
end
