class PayMoneyController < ApplicationController

  before_action :only => :guard do |s| s.get_service(params[:service_id], params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  before_action :only => :guard do |o| o.filter_connections params[:operation_id] end
  before_action do |s| s.basket_already_paid?(params[:basket_number]) end

  layout "payMoney"  
  # Inclure une sécurité au niveau de la fonction index basée sur l'adresse IP entrante. S'ssurer qu'elle correspond aux IP des services agréés (Les insérer dans une base de données locale ou externe?)  
  
  # params[:transaction_amount] = params[:magellan]
  # params[:account_number] = params[:colomb]
  # params[:password] = params[:drake] 
  
  def guard
    redirect_to action: "index"
  end
  
  def index
    # initialisation des feuilles de style des zones de saisie
    @shipping = ((session[:service]["transaction_amount"]).to_f * 0.02).round(2)
    @transaction_amount_css = @account_number_css = @password_css = "row-form"
  end
  
  def process_payment
    @transaction_amount = params[:magellan]
    @account_number = params[:colomb]
    @password = params[:drake]    
    @error_messages = []
    @success_messages = []
    @transaction_amount_css = @account_number_css = @password_css = "row-form"       
    @fields = [[@transaction_amount, "montant de la transaction", "transaction_amount_css"], [@account_number, "numéro de compte", "account_number_css"], [@password, "mot de passe", "password_css"]]
    
    @fields.each do |field|
      if field[0].blank?
        @error_messages << "Veuillez entrer le #{field[1]}."
        my_container = field[2]
        instance_variable_set("@#{my_container}", "row-form error")
        @error = true
      end
    end
    
    if @error
      render action: 'index'
    else
      @request = Typhoeus::Request.new("http://0.0.0.0:3001/wimboo/buy.xml", followlocation: true)
      #@request = Typhoeus::Request.new("http://localhost:8080/GATEWAY_HUB_NGSER/rest/#{session[:service]['id']}/#{session[:service]['operation_id']}/#{@basket_number}/#{@account_number}/#{@password}/1/#{@transaction_amount}", followlocation: true)
      
      @internal_com_request = "@response = Nokogiri.XML(request.response.body)
      @response.xpath('//status').each do |link|
      @status = link.content
      end
      session[:service]['transaction_status'] = @status"
      
      run_typhoeus_request(@request, @internal_com_request)
      
      if @status.to_s.strip == "3"
        @error = true
        @error_messages << "Veuillez vérifier votre numéro de compte et votre mot de passe."
      end
	  
      if(@error_messages.empty?)        
          Basket.create(:number => session[:service]["basket_number"], :service_id => session[:service_id], :payment_status => true, :operation_id => session[:service]["operation_id"])
          redirect_to generate_url('http://0.0.0.0:3001/paymoney/transaction_status', :basket_number => @basket_number, :status => @status)
        
      else
        render action: 'index'
      end
    end
  end

end
