class PayMoneyController < ApplicationController
  
  #@@url = "http://localhost:8080"
  @@url = Parameter.first.second_origin_url
  # Only for guard action, we check if service_id exists and initialize a session variable containing transaction_data
  #before_action :only => :guard do |s| s.get_service(params[:service_id], params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Only for guard action, we check if the session varable is initialized, if the operation_id is initialized and if transaction_amount is a number
  before_action :only => :guard do |o| o.filter_connections end
  #before_action :only => :guard do |r| r.authenticate_incoming_request(params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  # Vérifie que le panier n'a pas déjà été payé via paymoney
  #before_action :only => :guard do |s| s.basket_already_paid?(params[:basket_number]) end
  # Vérifie pour toutes les actions que la variable de session existe
  before_action :session_exists?, :except => [:create_account, :account, :credit_account, :add_credit, :transaction_acknowledgement] 
  #before_action :only => :process_payment do |s| s.basket_already_paid?(session[:service]['basket_number']) end
  before_action :except => [:create_account, :account, :credit_account, :add_credit, :transaction_acknowledgement] do |s| s.session_authenticated? end 

  layout "payMoney"  
  # Inclure une sécurité au niveau de la fonction index basée sur l'adresse IP entrante. S'ssurer qu'elle correspond aux IP des services agréés (Les insérer dans une base de données locale ou externe?)  
  
  # params[:transaction_amount] = params[:magellan]
  # params[:account_number] = params[:colomb]
  # params[:password] = params[:drake] 
  
  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end
  
  # Efface les parmètres du corps de la requête et affiche un friendly url dans le navigateur du client
  def index    
    @transaction_amount_css = @account_number_css = @password_css = "row-form"
    @wallet = Wallet.find_by_name("Paymoney")
    @wallet_currency = @wallet.currency
    @rate = get_change_rate(session[:currency].code, @wallet_currency.code)
    session[:basket]["transaction_amount"] = (session[:trs_amount] * @rate).round(2)
    @shipping = get_shipping_fee("Paymoney")
    
    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = Basket.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")
    if @basket.blank?
      @basket = Basket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, transaction_id: Time.now.strftime("%Y%m%d%H%M%S%L"), :fees => @shipping, :rate => @rate)
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate)
    end 
  end
  
  def process_payment
    @wallet = Wallet.find_by_name("Paymoney")
    @wallet_currency = @wallet.currency
    @shipping = get_shipping_fee("Paymoney")
    
    @transaction_status = "7"
    @transaction_amount = params[:magellan].to_f 
    @account_number = params[:colomb]
    @shipping = params[:shipping]
    @password = params[:drake]    
    @error_messages = []
    @success_messages = []
    @transaction_id = params[:transaction_id]
    @transaction_amount_css = @account_number_css = @password_css = "row-form"       
    @fields = [[@transaction_amount, "montant de la transaction", "transaction_amount_css"], [@account_number, "numéro de compte", "account_number_css"], [@password, "mot de passe", "password_css"]]
    @notified_to_back_office = nil
    
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
      @basket = Basket.find_by_transaction_id(@transaction_id) 
      # communication with paymoney
      @request = Typhoeus::Request.new("#{@@url}/PAYMONEY-NGSER/rest/OperationService/DebitOperation/2/#{@account_number}/#{@password}/#{@basket.transaction_amount + @basket.fees}", followlocation: true)     
      @internal_com_request = "@response = Nokogiri.XML(request.response.body)
      @response.xpath('//status').each do |link|
      @status = link.content
      end
      "      
      run_typhoeus_request(@request, @internal_com_request)
      
      if @status.to_s.strip == "1"
        
        @basket = Basket.find_by_transaction_id(@transaction_id)
        if @basket.blank?
          @basket = Basket.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, transaction_id: Time.now.strftime("%Y%m%d%H%M%S%L"), :fees => @shipping, :rate => @rate)
        else
          @basket.update_attributes(:transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => session[:basket]["transaction_amount"], :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate)
        end
        
        # Notification to ecommerce IPN
        Thread.new do
          ipn(@basket)
          if (ActiveRecord::Base.connection && ActiveRecord::Base.connection.active?)
            ActiveRecord::Base.connection.close
          end
        end
        
        # communication with back office
        @rate = get_change_rate(params[:cc], "EUR")
        @basket.update_attributes(compensation_rate: @rate)
        @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
        @fees_for_compensation = (@basket.fees * @rate).round(2)
        @request = Typhoeus::Request.new("#{@@url}/GATEWAY/rest/WS/#{session[:operation].id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/1", followlocation: true)
        
        @internal_com_request = "@response = Nokogiri.XML(request.response.body)
        @response.xpath('//status').each do |link|
        @status = link.content
        end
        "
        
        run_typhoeus_request(@request, @internal_com_request)
        
        if @status.to_s.strip == "1"
          # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
          
          
          @basket.update_attributes(:notified_to_back_office => true)
          
          # Redirection vers le site marchand                 
          redirect_to "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=paypal&transaction_amount=#{@basket.transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}"
        else
          #@basket.update_attributes(:conflictual_transaction_amount => params[:amt].to_f, :conflictual_currency => params[:cc].upcase)
          redirect_to "#{session[:service].url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=paypal&transaction_amount=#{@basket.transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}"
        end
      else
        @error = true
        @error_messages << "La transaction n'a pas abouti. Veuillez vérifier votre solde, votre numéro de compte et votre mot de passe."
        render action: 'index'
      end     
    end
  end
  
  def ipn(basket)
    @service = Service.find_by_id(basket.service_id)
    @request = Typhoeus::Request.new("#{@service.url_to_ipn}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=paypal&transaction_amount=#{@basket.transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}", followlocation: true, method: :post)
    # wallet=05ccd7ba3d
    @request.run
    @response = @request.response
    #if @response.to_s == "200" and @response.body.blank?
      basket.update_attributes(:notified_to_ecommerce => true)
    #end
  end
  
  def transaction_acknowledgement
    @status = "0"
    @basket = Basket.find_by_transaction_id(params[:transaction_id])
    if !@basket.blank?
      if @basket.payment_status == true
        @status = "1"
      end
    else
      @status = "0"
    end
    render :text => @status
  end
  
  def account
    @lastnamecss = @firstnamecss = @agecss = @emailcss = @phone_numbercss = "row-form"
  end
  
  def create_account
    @error_messages = @success_messages = []    
    @error = @success = false
    @firstname = params[:firstname]
    @lastname = params[:lastname]
    @age = params[:age].strip
    @email = params[:email]
    @phone_number = params[:phone_number].strip
    @lastnamecss = @firstnamecss = @agecss = @emailcss = @phone_numbercss = "row-form"
    
    if !name_correct?(@firstname) 
      @error = true
      @firstnamecss = "row-form error"
      @error_messages << "Le nom n'est pas valide"
    end
    if !name_correct?(@lastname) 
      @error = true
      @lastnamecss = "row-form error"
      @error_messages << "Le prénom n'est pas valide"
    end
    if not_a_number?(@age) 
      @error = true
      @agecss = "row-form error"
      @error_messages << "L'âge n'est pas valide"
    end
    if not_a_number?(@phone_number)  or (@phone_number.size != 8 and @phone_number.size != 11 )
      @error = true
      @phone_numbercss = "row-form error"
      @error_messages << "Le numéro de téléphone n'est pas valide"
    end
    if !valid_email?(@email)
      @error = true
      @emailcss = "row-form error"
      @error_messages << "L'email n'est pas valide"
    end
    
    if(@error)
          
    else
      @request = Typhoeus::Request.new("#{@@url}/PAYMONEY-NGSER/rest/CompteService/CreateCompte/#{@firstname}/#{@lastname}/#{@age}/#{@phone_number}/#{@email}", followlocation: true)
      
      @internal_com_request = "@response = Nokogiri.XML(request.response.body)"
      
      run_typhoeus_request(@request, @internal_com_request)
      if(!@response.blank?)
        if @response.xpath('//compte').blank? or @response.xpath('//compte').blank? or @response.xpath('//compteNumero').blank?
          @error = true
          @error_messages << "Ce compte existe déjà"
        else
          @success = true
          @success_messages << "Votre compte a bien été créé."
        end
      end
    end
    render action: 'account'
  end
  
  def credit_account
    @accountcss = @passwordcss = @amountcss = "row-form"
  end
  
  def add_credit
    @error_messages = @success_messages = []    
    @accountcss = @passwordcss = @amountcss = "row-form"
    @error = @success = false
    @account = params[:account]
    @password = params[:password]
    @pin = params[:pin].strip
    
    # Vérification des champs   
    if @account.blank?
      @error = true
      @error_messages << "Le numéro de compte n'est pas valide"
      @accountcss = "row-form error"
    end
=begin
    if @password.blank?
      @error = true
      @error_messages << "Le mot de passe n'est pas valide"
      @passwordcss = "row-form error"
    end
=end
    if @pin.blank?
      @error = true
      @error_messages << "Le montant n'est pas valide"
      @amountcss = "row-form error"
    end
    
    if(@error)
      
    else
      # Envoi d'une requête à la plateforme EVD pour vérifier la validité du PIN
      @request = Typhoeus::Request.new("#{@@url}/GATEWAY/rest/ES/VerifyPin/#{@pin}", followlocation: true)
        
      @internal_com_request = "@response = Nokogiri.XML(request.response.body)"
      run_typhoeus_request(@request, @internal_com_request)
      
      if !@response.blank? and !@response.xpath('//pin').blank? and !@response.xpath('//pin').at("pinStatus").blank?
        @pin_status = @response.xpath('//pin').at("pinStatus").text
        # Si le PIN est valide
        if @pin_status == "1"
          # Envoi de la requête de rechargement de compte
          @amount = @response.xpath('//pin').at("pinMontant").text
          @request = Typhoeus::Request.new("#{@@url}/PAYMONEY-NGSER/rest/OperationService/CreditOperation/1/#{@account}/#{@amount.to_i.abs}", followlocation: true)
          #@request = Typhoeus::Request.new("#{@@url}/PAYMONEY-NGSER/rest/OperationService/CreditOperation/1/#{@account}/#{@password}/#{@amount.to_i.abs}", followlocation: true)
        
          @internal_com_request = "@response = Nokogiri.XML(request.response.body)"
          run_typhoeus_request(@request, @internal_com_request)
          
          if(!@response.blank? and @response.xpath('//status').at("idStatus").text == "1")
            @success = true
            @success_messages << "Le compte #{@account} a été crédité de #{@amount.to_i.abs} unités"
            @request = Typhoeus::Request.new("#{@@url}/GATEWAY/rest/ES/ChangeStatus/#{@pin}", followlocation: true)
        
            @internal_com_request = "@response = Nokogiri.XML(request.response.body)"
            run_typhoeus_request(@request, @internal_com_request)
            if(!@response.blank? and @response.xpath('//pin').at("pinStatus").text == "1")
              # record into database
            end
          else
            @error = true
            @error_messages << "Veuillez vérifier votre Numéro de compte - Mot de passe"
          end
        else
          # Gestion des erreurs en cas de non validité du PIN
          case @pin_status
          when "0" then
            @error = true
            @error_messages << "Ce code PIN n'existe pas"
          when "2" then
            @error = true
            @error_messages << "Ce code PIN a déjà été utilisé"
          when "3" then
            @error = true
            @error_messages << "Ce code PIN a expiré"
          else
            @error = true
            @error_messages << "Ce code PIN n'est pas valide"
          end
        end
      else
        @error = true
        @error_messages << "Votre PIN n'a pas pu être validé. Veuillez ressayer ou contacter l'administrateur"
      end        
    end    
    render action: 'credit_account'
  end

end
