class OrangeMoneyCiController < ApplicationController
  ##before_action :only => :guard do |o| o.filter_connections end
  ##before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  ##before_action :except => [:ipn, :transaction_acknowledgement] do |s| s.session_authenticated? end
  
  layout "orange_money_ci"
  
  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"    
  end
  
  def index
    # récupération du wallet, de la monnaie utilisée par le wallet, du taux de change entre la monnaie envoyée par le ecommerce et celle du wallet, conversion du montant envoyé par le ecommerce en celui supporté par le wallet et affichage des frais de transfert
    @wallet = Wallet.find_by_name("Orange Money CI")
    @wallet_currency = @wallet.currency    
    @rate = get_change_rate(session[:currency].code, @wallet_currency.code)
    session[:basket]["transaction_amount"] = (session[:trs_amount].to_f.ceil * @rate).ceil
    @shipping = get_shipping_fee("Orange Money CI")
    @parameter = Parameter.first
    
    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = OrangeMoneyCiBasket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")
    if @basket.blank?
      @basket = OrangeMoneyCiBasket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :transaction_amount => session[:trs_amount].to_f.ceil, :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, transaction_id: Time.now.strftime("%Y%m%d%H%M%S%L"), :fees => @shipping, :rate => @rate)
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount].to_f.ceil, :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate)
    end   
     
    initialize_session  
    unless session_initialized
      redirect_to error_page_path
    end
  end
  
  def payment_result_listener
    render text: params.except(:controller, :action)
  end
  
  def ipn
    render text: params.except(:controller, :action)
  end
  
  #private
    def initialize_session
      @parameter = Parameter.first
      #@basket = OrangeMoneyCiBasket.find_by_transaction_id(@transaction_id)
      request = Typhoeus::Request.new(@parameter.orange_money_ci_initialization_url, followlocation: true, method: :post, body: "merchantid=1f3e745c66347bc2cc9492d8526bfe040519396d7c98ad199f4211f39dfd6365&amount=#{session[:basket]["transaction_amount"] + (@basket.fees.ceil rescue @basket.first.fees.ceil)}&sessionid=#{@basket.transaction_id rescue nil}&purchaseref=#{session[:basket]["basket_number"]}", headers: {:'Content-Type'=> "application/x-www-form-urlencoded"})

      request.on_complete do |response|
        if response.success?
          @session_id = response.body.strip
        elsif response.timed_out?
          @session_id = nil
        elsif response.code == 0
          @session_id = nil
        else
          @session_id = nil
        end
      end

      request.run
    end
    
    def session_initialized
      (@session_id != "access denied" && @session_id.length > 30) ? true : false
    end
end
