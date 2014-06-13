class MainController < ApplicationController
  #@@url = "http://localhost:8080"
  @@url = "http://41.189.40.193:8080"
  # Only for guard action, we check if service_id exists and initialize a session variable containing transaction_data
  before_action :only => :guard do |s| s.get_service_by_token(params[:service_token], params[:operation_token], params[:order], params[:transaction_amount]) end
  # Only for guard action, we check if the session varable is initialized, if the operation_id is initialized and if transaction_amount is a number
  before_action :only => :guard do |o| o.filter_connections end
  #before_action :only => :guard do |r| r.authenticate_incoming_request(params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Vérifie que le panier n'a pas déjà été payé via paypal
  before_action :only => :guard do |s| s.basket_already_paid?(params[:basket_number]) end
  # Vérifie pour toutes les actions que la variable de session existe
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement]
  # Si l'utilisateur ne s'est pas connecté en passant par guard, on le rejette
  before_action :except => :guard do |s| s.session_authenticated? end 

  layout "main"
  
  # Reçoit les requêtes venant des différents services
  def guard
    session[:b83eff1c1b3fdbb26153075044297e91] = SecureRandom.hex
    redirect_to action: "index"       
  end  
  
  def index
    @countries = Country.where("published IS TRUE").order("name ASC")
    @international = Country.find_by_name("International")
    @wallets = Wallet.where("published IS NOT FALSE AND country_id = #{@international.id}").order("name ASC")
    @wallets.count < 4 ? session[:visible_slices] = @wallets.count : session[:visible_slices] = 3
  end
    
end
