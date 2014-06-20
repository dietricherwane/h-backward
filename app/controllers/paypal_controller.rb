class PaypalController < ApplicationController
  #@@url = "http://localhost:8080"
  @@url = "http://41.189.40.193:8080"
  # Only for guard action, we check if service_id exists and initialize a session variable containing transaction_data
  #before_action :only => :guard do |s| s.get_service(params[:service_id], params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Only for guard action, we check if the session varable is initialized, if the operation_id is initialized and if transaction_amount is a number
  before_action :only => :guard do |o| o.filter_connections end
  #before_action :only => :guard do |r| r.authenticate_incoming_request(params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Vérifie que le panier n'a pas déjà été payé via paypal
  #before_action :only => :guard do |s| s.basket_already_paid?(params[:basket_number]) end
  # Vérifie pour toutes les actions que la variable de session existe
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :except => [:ipn, :transaction_acknowledgement] do |s| s.session_authenticated? end 

  layout "paypal"
  
  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"    
  end  
  
  # Efface les parmètres du corps de la requête et affiche un friendly url dans le navigateur du client
  def index
    @wallet = Wallet.find_by_name("Paypal")
    @wallet_currency = @wallet.currency    
    @rate = get_change_rate(session[:currency].code, @wallet_currency.code)
    session[:basket]["transaction_amount"] = (session[:trs_amount] * @rate).round(2)
    @shipping = get_shipping_fee("Paypal")
    
    if PaypalBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}' AND notified_to_back_office IS TRUE").blank?
      @temporary_basket = PaypalBasket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :transaction_amount => (session[:basket]["transaction_amount"].to_f), transaction_id: Time.now.strftime("%Y%m%d%H%M%S%L"), :fees => @shipping)
    else
      @temporary_basket = PaypalBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}' AND notified_to_back_office IS TRUE").first
    end    
  end
  
  #Instant Payment Notification de paypal, transparent pour l'utilisateur
  def ipn
    render :nothing => true, status: 200
    @gross = params[:payment_gross]
    @fees = params[:payment_fee]
    @status = ""
    @parameters = {"cmd" => "_notify-validate"}.merge(params.except(:action, :controller))
    @request = Typhoeus::Request.new("https://www.sandbox.paypal.com/cgi-bin/webscr", followlocation: true, params: @parameters, method: :post)
    @request.run
    @response = @request.response
    if @response.body == "VERIFIED"
      @basket = PaypalBasket.where("transaction_id = '#{params[:custom].to_s}' AND transaction_amount = #{@gross.to_f}")
      if !@basket.blank?
        @basket = PaypalBasket.find_by_transaction_id(params[:custom].to_s)
        if @basket.payment_status != true
          @basket.update_attributes(:payment_status => true) 
        end
        if @basket.notified_to_back_office != true
          # Notification au back office du HUB
          notify_to_back_office(@basket, "#{@@url}/GATEWAY/rest/WS/#{@basket.operation_id}/#{@basket.number}/#{@basket.transaction_id}/#{@gross.to_f + @basket.fees}/#{@basket.fees}/2")
        end
        # Notification au back office du ecommerce
        if @basket.notified_to_ecommerce != true
          @service = Service.find_by_id(@basket.service_id)
          @request = Typhoeus::Request.new("#{@service.url_to_ipn}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=paypal&transaction_amount=#{@basket.transaction_amount}", followlocation: true, method: :post)
          # wallet=e6da96e284
          @request.run
          @response = @request.response
          if @response.to_s == "200" and @response.body.blank?
            @basket.update_attributes(:notified_to_ecommerce => true)
          end
        end
      end
    end
  end
    
  def transaction_acknowledgement
    @status = "0"
    @basket = PaypalBasket.find_by_transaction_id(params[:transaction_id])
    if !@basket.blank?
      if @basket.payment_status == true
        @status = "1"
      end
    else
      @status = "0"
    end
    render :text => @status
  end
  
  # Lorsque l'utilisateur finit son achat sur paypal, il est redirigé vers cette fonction pour authentifier  la transaction, l'historiser et envoyer le reporting au back end
  def payment_result_listener
    @error_messages = []
    @status = ""
    @request = Typhoeus::Request.new("https://www.sandbox.paypal.com/cgi-bin/webscr", method: :post, params: {cmd: "_notify-sync", tx: "#{params[:tx]}", at: "wc9rbATkeBqy488jdxnQeXHsv9ya8Sh6Pq_DST3BihQ4oV2-De3epJilfKG"})
    @request.run
    @response = @request.response
    if(params[:st] == "Completed")
      #@basket = PaypalBasket.find_by_transaction_id(params[:cm].to_s)
      @basket = PaypalBasket.find_by_transaction_id(params[:cm])
      #.where("transaction_id = '#{params[:cm].to_s}' AND transaction_amount = #{params[:amt].to_f}")
      if !@basket.blank? and (params[:amt].to_f + params[:tax].to_f) == (@basket.transaction_amount + @basket.fees) 
        # Le panier a été payé
        if @basket.payment_status == true
          if @basket.notified_to_back_office != true
            notify_to_back_office(@basket, "#{@@url}/GATEWAY/rest/WS/#{session[:operation].id}/#{session[:basket]['basket_number']}/#{session[:basket]['basket_number']}/#{params[:amt].to_f + params[:tax].to_f}/#{params[:tax].to_f}/2")         
          end
          @basket.update_attributes(:payment_status => true)
          redirect_to "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=paypal&transaction_amount=#{@basket.transaction_amount}"
          #redirect_to "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1"
        else
          @basket.update_attributes(:payment_status => true)
          notify_to_back_office(@basket, "#{@@url}/GATEWAY/rest/WS/#{session[:operation].id}/#{session[:basket]['basket_number']}/#{session[:basket]['basket_number']}/#{params[:amt].to_f + params[:tax].to_f}/#{params[:tax].to_f}/2")
              
          redirect_to "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=paypal&transaction_amount=#{@basket.transaction_amount}"
          #redirect_to "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1"
          #redirect_to "https://www.wimboo.net/payments/ipn.php?order_id=#{params[:cm]}&statut_id=2"
        end
      else
        redirect_to error_page_path
        #redirect_to "#{session[:service].url_on_error}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0"
      end
    else
      redirect_to error_page_path
      #redirect_to "#{session[:service].url_on_error}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0"
    end    
  end
  
  def notify_to_back_office(basket, url)
    #if basket.payment_status != true
      #basket.update_attributes(:payment_status => true)  
    #end           
    @request = Typhoeus::Request.new(url, followlocation: true)
    @internal_com_request = "@response = Nokogiri.XML(request.response.body)
    @response.xpath('//status').each do |link|
    @status = link.content
    end
    "   
    run_typhoeus_request(@request, @internal_com_request)
    
    if @status.to_s.strip == "1"
      basket.update_attributes(:notified_to_back_office => true)
    end
  end

end
