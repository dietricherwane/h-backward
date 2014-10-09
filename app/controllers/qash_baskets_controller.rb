class QashBasketsController < ApplicationController
  @@second_origin_url = Parameter.first.second_origin_url
  
  ##before_action :only => :guard do |o| o.filter_connections end
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement, :payment_result_listener]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :except => [:ipn, :transaction_acknowledgement, :payment_result_listener] do |s| s.session_authenticated? end
  
  layout "qash"
  
  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"    
  end
  
  def index
    # récupération du wallet, de la monnaie utilisée par le wallet, du taux de change entre la monnaie envoyée par le ecommerce et celle du wallet, conversion du montant envoyé par le ecommerce en celui supporté par le wallet et affichage des frais de transfert
    @wallet = Wallet.find_by_name("Qash")
    @wallet_currency = @wallet.currency    
    @rate = get_change_rate(session[:currency].code, @wallet_currency.code)
    session[:basket]["transaction_amount"] = (session[:trs_amount].to_f.ceil * @rate).ceil
    @shipping = get_shipping_fee("Qash").ceil
    @parameter = Parameter.first
    
    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = QashBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")
    if @basket.blank?
      @basket = QashBasket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :original_transaction_amount => session[:trs_amount], :transaction_amount => session[:trs_amount].to_f.ceil, :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, transaction_id: Time.now.strftime("%Y%m%d%H%M%S%L"), :fees => @shipping, :rate => @rate)
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount].to_f.ceil, :original_transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate)
    end   
  end
  
  def payment_result_listener
    @qash_transaction_id = params[:TXN_ID]
    @transaction_id = params[:ID_OPERATION]
    @merchant_id = params[:REF_COMMERCE]
    @transaction_amount = params[:MONTANT]
    @devise = params[:DEVISE]
    @status = params[:ETAT]
    @name = params[:NOM_PREN]
        
    if valid_result_parameters
      if valid_transaction
        @basket = QashBasket.find_by_transaction_id(@transaction_id)
        if @basket
          @devise.to_s.upcase.strip == "CFA" ? (@devise = "XAF") : (@devise = nil)
          if (@basket.paid_transaction_amount + @basket.fees) == @transaction_amount.to_f  && @basket.currency.code.upcase == @devise.upcase
                        
            # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
            @rate = get_change_rate(@devise, "EUR")

            @basket.update_attributes(payment_status: true, qash_transaction_id: @qash_transaction_id, compensation_rate: @rate)
            
            @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
            @fees_for_compensation = (@basket.fees * @rate).round(2)
            
            # Notification au back office du hub
            notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{@basket.operation.id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")    
            
            # Redirection vers le site marchand                 
            redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=qash&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
          else
            @basket.update_attributes(:conflictual_transaction_amount => @transaction_amount.to_f, :conflictual_currency => @devise.to_s[0..2].upcase)
            redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=qash&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}"
          end 
        else
          redirect_to error_page_path
        end
      else
        redirect_to error_page_path
      end
    else
      redirect_to error_page_path
    end
  end
  
  def valid_result_parameters
    if !@qash_transaction_id.blank? && !@transaction_id.blank? && !@transaction_amount.blank? && !@devise.blank? && !@status.blank? && !@name.blank? && !@merchant_id.blank?
      return true
    else
      return false
    end
  end
  
  def valid_transaction
     parameter = Parameter.first
    request = Typhoeus::Request.new("#{parameter.qash_verify_url}TXN_ID=#{@qash_transaction_id}&ID_OPERATION=#{@transaction_id}&REF_COMMERCE=#{@merchant_id}&MONTANT=#{@transaction_amount}&DEVISE=#{@devise}&ETAT=#{@status}&NOM_PREN=#{@name}", followlocation: true, method: :get)

    request.on_complete do |response|
      if response.success?
        @result = response.body.strip rescue nil
      else
        @result = nil
      end
    end

    request.run
    
    @result == "VERIFIED" ? true : false
  end
  
  def ipn
    render text: params.except(:controller, :action)
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
