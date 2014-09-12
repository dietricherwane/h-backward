class PaypalController < ApplicationController
  @@second_origin_url = Parameter.first.second_origin_url
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
    # récupération du wallet, de la monnaie utilisée par le wallet, du taux de change entre la monnaie envoyée par le ecommerce et celle du wallet, conversion du montant envoyé par le ecommerce en celui supporté par le wallet et affichage des frais de transfert
    @wallet = Wallet.find_by_name("Paypal")
    @wallet_currency = @wallet.currency    
    @rate = get_change_rate(session[:currency].code, @wallet_currency.code)
    session[:basket]["transaction_amount"] = (session[:trs_amount] * @rate).round(2)
    @shipping = get_shipping_fee("Paypal")
    
    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = PaypalBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")
    if @basket.blank?
      @basket = PaypalBasket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, transaction_id: Time.now.strftime("%Y%m%d%H%M%S%L"), :fees => @shipping, :rate => @rate)
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate)
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
      @basket = PaypalBasket.find_by_transaction_id(params[:custom].to_s)
      if !@basket.blank?       
        if @basket.payment_status != true
          @basket.update_attributes(:payment_status => true) 
        end
        if @basket.notified_to_back_office != true
          @rate = get_change_rate(params[:cc], "EUR")
          @@basket.update_attributes(compensation_rate: @rate)
          @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
          @fees_for_compensation = (@basket.fees * @rate).round(2)
          
          # Notification au back office du hub
          notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{session[:operation].id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2") 
        end
        # Notification au back office du ecommerce
        if @basket.notified_to_ecommerce != true
          @service = Service.find_by_id(@basket.service_id)
          @request = Typhoeus::Request.new("#{@service.url_to_ipn}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=paypal&transaction_amount=#{@basket.transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}", followlocation: true, method: :post)
          # wallet=e6da96e284
          @request.run
          @response = @request.response
          #if @response.to_s == "200" and @response.body.blank?
            @basket.update_attributes(:notified_to_ecommerce => true)
          #end
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
    # On vérifie que les données reçues par le listener proviennent bien de paypal
    @error_messages = []
    @status = ""
    @request = Typhoeus::Request.new("https://www.sandbox.paypal.com/cgi-bin/webscr", method: :post, params: {cmd: "_notify-sync", tx: "#{params[:tx]}", at: "wc9rbATkeBqy488jdxnQeXHsv9ya8Sh6Pq_DST3BihQ4oV2-De3epJilfKG"})
    @request.run
    @response = @request.response
    
    # On vérifie que la transaction a été effectuée
    if(params[:st] == "Completed")
      @basket = PaypalBasket.find_by_transaction_id(params[:cm])
      # On vérifie que la panier existe
      if !@basket.blank?
        # On vérifie que le montant ainsi que les frais payés et la monnaie correspondent à ceux stockés dans la base de données
        if (@basket.paid_transaction_amount + @basket.fees) == params[:amt].to_f  and @basket.currency.code.upcase == params[:cc].upcase
          @basket.update_attributes(:payment_status => true)  
          
          # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
          @rate = get_change_rate(params[:cc], "EUR")
          @basket.update_attributes(compensation_rate: @rate)
          @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
          @fees_for_compensation = (@basket.fees * @rate).round(2)
          
          # Notification au back office du hub
          notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{session[:operation].id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")    
          
          # Redirection vers le site marchand                 
          redirect_to "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=paypal&transaction_amount=#{@basket.transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        else
          (params[:cc].length > 3) ? params[:cc][0,3] : false
          # Le montant payé ou la monnaie n'est pas celui ou celle envoyé au wallet pour ce panier
          @basket.update_attributes(:conflictual_transaction_amount => params[:amt].to_f, :conflictual_currency => params[:cc].upcase)
          redirect_to "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=paypal&transaction_amount=#{@basket.transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}"
        end
      else
        # On vérifie que le panier existe
        redirect_to error_page_path
        #redirect_to "#{session[:service].url_on_error}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0"
      end
    else
      # L'origine de la transaction n'a pas pu être vérifiée
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
