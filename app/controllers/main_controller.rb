class MainController < ApplicationController
  # Only for guard action, we check if service_id exists and initialize a session variable containing transaction_data
  before_action :only => :guard do |s| s.get_service_by_token(params[:currency], params[:service_token], params[:operation_token], params[:order], params[:transaction_amount], params[:paymoney_account_number], params[:paymoney_password]) end
  # Only for guard action, we check if the session varable is initialized, if the operation_id is initialized and if transaction_amount is a number
  before_action :only => [:guard, :index] do |o| o.filter_connections end
  ##before_action :only => :guard do |r| r.authenticate_incoming_request(params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Vérifie que le panier n'a pas déjà été payé via paypal
  before_action :only => :guard do |s| s.basket_already_paid?(session[:basket]["basket_number"]) end
  # Vérifie pour toutes les actions que la variable de session existe
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement]
  # Si l'utilisateur ne s'est pas connecté en passant par guard, on le rejette
  before_action :except => :guard do |s| s.session_authenticated? end

  #layout "main"

  layout :select_layout

  def select_layout
    if session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559'
      return "guce"
    else
      return "main"
    end
  end

  # Reçoit les requêtes venant des différents services
  def guard
    session[:b83eff1c1b3fdbb26153075044297e91] = SecureRandom.hex
    redirect_to action: "index"
  end

  def index
    @countries = Country.where("published IS TRUE").order("name ASC")
    @international = Country.find_by_name("Banques")
    @available_wallets = session[:service].available_wallets.where(published: true, wallet_id: session[:service].wallets.where(country_id: @international.id).map{|w| w.id})

  end

end
