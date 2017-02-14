class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  #protect_from_forgery with: :null_session

  # Génère l'identifiant de transaction
  def generate_transaction_id(len = 8)
    chars_source = %w{ 0 1 2 3 4 5 6 7 8 9}
    code = (0...len).map{ chars_source.to_a[rand(chars_source.size)] }.join
    code
  end

  # Initialise la variable de session contenant les informations sur la transaction
  def get_service_by_token(currency, service_token, operation_token, order, transaction_amount, id, paymoney_account_number, paymoney_password)
    # si la devise envoyee n'existe pas, on renvoie la page d'erreur
    currency_exists?(currency)
    session[:currency] = @currency.first
    @service = Service.where("authentication_token = '#{service_token}' AND published IS NOT FALSE")
    unless @service.blank?
      @service = @service.first
      @operation = Operation.where("authentication_token = '#{operation_token}' AND service_id = #{@service.id} AND published IS NOT FALSE")
      unless @operation.blank?
        @operation = @operation.first
        unless not_a_number?(transaction_amount)
          session[:service] = Service.find_by_authentication_token(service_token)
          session[:operation] = Operation.find_by_authentication_token(operation_token)
          session[:trs_amount] = transaction_amount.to_f.round(2)
          session[:basket] = {"basket_number" => "#{order}", "transaction_amount" => "#{transaction_amount.to_f.round(2)}"}
          session[:paymoney_account_number] = paymoney_account_number
          session[:paymoney_password] = paymoney_password
          unless session[:paymoney_account_number].blank?
            paymoney_token_url = "#{Parameter.first.paymoney_wallet_url}/PAYMONEY_WALLET/rest/check2_compte/#{session[:paymoney_account_number]}"
            session[:paymoney_account_token] = (RestClient.get(paymoney_token_url) rescue "")
            if session[:paymoney_account_token].blank? || session[:paymoney_account_token] == "null"
              redirect_to "#{session[:service].url_on_basket_already_paid}?status_id=4"
            end
          end
        end
      end
    end
  end

  # Verifie que la devise existe dans la base de donnees
  def currency_exists?(currency)
    @currency = Currency.where("code = '#{currency.upcase}' AND published IS TRUE")
    if @currency.blank?
      redirect_to error_page_path
    end
  end

  # Initialise la variable de session contenant les informations sur la transaction
  def get_service(service_id, operation_id, basket_number, transaction_amount)
    @service = Service.find_by_code(service_id)
    unless @service.blank?
      @operation = @service.operations.find_by_id(operation_id)
      unless @operation.blank?
        unless not_a_number?(transaction_amount)
          session[:service] = @service
          session[:operation] = @operation
          session[:basket] = {"basket_number" => "#{basket_number}", "transaction_amount" => "#{transaction_amount.to_f}"}
        end
      end
    end
  end

  def get_change_rate(from, to)
    @from = from
    @to = to
    @rate = 0
    if @from ==@to
      @rate = 1
    else
      @rate = ActiveRecord::Base.connection.execute("SELECT * FROM currencies_matches WHERE first_code = '#{@from}' AND second_code = '#{@to}'").first["rate"].to_f
    end
    @rate
  end

  # S'assure que la variable de session existe
  def session_exists?
    if (session[:service].blank? or session[:operation].blank? or session[:basket].blank?)
      #redirect_to session[:service].url_on_session_expired
      redirect_to error_page_path
    end
  end

  def session_authenticated?
    if session[:b83eff1c1b3fdbb26153075044297e91].blank?
      redirect_to error_page_path
    end
  end

  # Vérifie que la variable de session existe, que l'opération demandée existe, que le montant de la transaction est numérique
  def filter_connections
    if session[:service].blank? or session[:operation].blank? or session[:basket].blank? or not_a_number?(session[:basket]["transaction_amount"])
      #redirect_to session[:service].url_on_error
      redirect_to error_page_path
    end
  end

  # Vérifie que le panier n'a pas déjà été payé
  def basket_already_paid?(basket_number)
    if session[:service].blank?
      #redirect_to session[:service].url_on_session_expired
      redirect_to error_page_path
    else
      @basket = session[:service].baskets.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @paypal_basket = session[:service].paypal_baskets.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @orange_money_ci_basket = session[:service].orange_money_ci_baskets.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @qash_basket = session[:service].qash_baskets.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @delayed_payment = session[:service].delayed_payments.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @mtn_ci_basket = session[:service].mtn_cis.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      @uba_basket = session[:service].ubas.where("number = '#{basket_number}' AND operation_id = '#{session[:operation].id}'")
      #session[:service_id] = @service.id
      if ((!@basket.blank? and @basket.first.payment_status.eql?(true)) or (!@mtn_ci_basket.blank? and @mtn_ci_basket.first.payment_status.eql?(true))  or (!@paypal_basket.blank? and @paypal_basket.first.payment_status.eql?(true)) or (!@delayed_payment.blank? and @delayed_payment.first.payment_status.eql?(true)) or (!@orange_money_ci_basket.blank? and @orange_money_ci_basket.first.payment_status.eql?(true)) or (!@qash_basket.blank? and @qash_basket.first.payment_status.eql?(true)) or (!@uba_basket.blank? and @uba_basket.first.payment_status.eql?(true)))
        redirect_to "#{session[:service].url_on_basket_already_paid}?status_id=2"
        #redirect_to error_page_path
      end
    end
  end

  def generate_url(url, params = {})
    uri = URI(url)
    uri.query = params.to_query
    uri.to_s
  end

  def run_typhoeus_request(request, code_on_success)
    @error_messages = []
    request.on_complete do |response|
      if response.success?
        eval(code_on_success)
      elsif response.timed_out?
        @error_messages << "Délai d'attente de la demande dépassé. Veuillez contacter l'administrateur."
        @error = true
      elsif response.code == 0
        #@error_messages << "L'URL demandé n'existe pas. Veuillez contacter l'administrateur."
        @error = true
      else
        #@error_messages << "Une erreur s'est produite. Veuillez contacter l'administrateur"
        @error = true
      end
    end
    hydra = Typhoeus::Hydra.hydra
	  hydra.queue(request)
	  hydra.run
  end



  def authenticate_incoming_request(operation_id, basket_number, transaction_amount)
    @request = Typhoeus::Request.new(session[:service]["url_to_authenticate_incoming_request"], method: :post, params: {operation_id: "#{operation_id}", basket_number: "#{basket_number}", transaction_amount: "#{transaction_amount}"})
    @request.run
    @response = @request.response
    if(params[:status] != session[:service]["authentication_token"])
      redirect_to error_page_path
    end
  end

  def not_a_number?(n)
  	n.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? true : false
  end

  def name_correct?(name)
    if(name.blank? or name.length == 1)
      false
    else
      true
    end
  end

  def valid_email?(email)
    /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i.match(email).blank? ? false : true
  end

  # Manages transaction acknowledgements fo all wallets
  def generic_transaction_acknowledgement(my_model, transaction_id)
    status = "0"
    order = my_model.find_by_transaction_id(transaction_id)
    if order
      if order.payment_status == true
        status = "1"
      end
    end
    render :text => status
  end

  # Initialize mandatory variables before displaying the payment validation form to the user
  # récupération du wallet, de la monnaie utilisée par le wallet, du taux de change entre la monnaie envoyée par le ecommerce et celle du wallet, conversion du montant envoyé par le ecommerce en celui supporté par le wallet et affichage des frais de transfert
  def initialize_customer_view(wallet_authentication_token, set_transaction_amount, set_shipping_fee)
    @wallet = Wallet.find_by_authentication_token(wallet_authentication_token)
    @wallet_currency = @wallet.currency
    @rate = get_change_rate(session[:currency].code, @wallet_currency.code)
    send(set_transaction_amount)
    # Si la transacation ne provient pas du guce, on calcule les frais normalement.
    if session[:service].authentication_token != '57813dc7992fbdc721ca5f6b0d02d559'
      @shipping = send(set_shipping_fee)
    end
  end

  def ceiled_transaction_amount
    @transaction_amount = (session[:trs_amount].to_f.ceil * @rate).ceil
  end

  def unceiled_transaction_amount
    @transaction_amount = (session[:trs_amount] * @rate).round(2)
  end

  def ceiled_shipping_fee
    return get_shipping_fee.ceil
  end

  def unceiled_shipping_fee
    return get_shipping_fee
  end

  # Récupère les frais de transaction en fonction du wallet
  def get_shipping_fee
    @fee = 0

    if !session[:service].fee.blank?
      @fee = ((@transaction_amount.to_f * (session[:service].fee || 0)) / 100).round(2)
    else
      if @wallet
        if(@wallet.percentage)
          @fee = (((@transaction_amount).to_f * @wallet.fee) / 100).round(2)
        else
          @fee = @wallet.fee
        end
      end
    end
    return @fee
  end

  def get_service_logo(token)
    parameters = Parameter.first
    request = Typhoeus::Request.new("#{parameters.front_office_url}/ecommerce/get_logo/#{token}", method: :get, followlocation: true)
    request.run
    response = request.response

    #if response.success?
      @service_logo = "#{parameters.front_office_url}#{response.body}"
    #else
      #@service_logo = "/images/medium/missing.png"
    #end
  end

  # Use authentication_token to update wallet used
  def update_wallet_used(basket, authentication_token)
    @available_wallet = basket.service.available_wallets.where(wallet_id: Wallet.find_by_authentication_token(authentication_token).id).first rescue nil
    @available_wallet.update_attribute(:wallet_used, true) rescue nil
  end

  # Update in available_wallet the number of successful transactions
  def update_number_of_succeed_transactions
    @available_wallet.update_attribute(:succeed_transactions,  (@available_wallet.succeed_transactions.to_i + 1)) rescue nil
  end

  # Update in available_wallet the number of failed transactions
  def update_number_of_failed_transactions
    @available_wallet.update_attribute(:failed_transactions,  (@available_wallet.failed_transactions.to_i + 1)) rescue nil
  end

  # Handle GUCE requests
  # Is the current request incoming from the GUCE
  def guce_request?
    if session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559'
      set_guce_transaction_amount
    end
  end

  # Make a request to the back office to get the last transaction amount
  def set_guce_transaction_amount
    parameters = Parameter.first

#=begin

      request = Typhoeus::Request.new("#{parameters.guce_back_office_url}/GPG_GUCE/rest/Mob_Mon/Check/#{session[:basket]['basket_number']}/#{session[:basket]['transaction_amount']}", method: :get, followlocation: true)
      request.run

      response = (Nokogiri.XML(request.response.body) rescue nil)
#=end
=begin
      response = Nokogiri.XML(%Q{<ns3:response xmlns="epayment/common" xmlns:ns2="epayment/common-response" xmlns:ns3="epayment/check-response" xmlns:ns4="epayment/common-request">
<ns2:header>
<message_id>GOOD</message_id>
<ns2:result>0</ns2:result>
</ns2:header>
<bill>
<date>2015-03-31T16:44:51.464</date>
<type>SAD</type>
<number>SAD201500000168</number>
<amount>24980000</amount>
<document_no>2015-CIABE-L-290</document_no>
<document_date>2015-03-31T00:00:00.000</document_date>
<company_code>0000058J</company_code>
<company_name_address>
MANE BUSINESS SERVICE (MBS) 18 BP 1182 ABIDJAN 18 RCI
</company_name_address>
<declarant_code>00416J</declarant_code>
<declarant_name_address>
CATTA-CI SARL 09 BP 1327 ABIDJAN 09 TREICHVILLE-VGE-IMMEUBLE LA BALANCE
</declarant_name_address>
<transaction_id>udgAzxVkpQlN</transaction_id>
<payment_no>639</payment_no>
<payment_date>2015-04-01T15:08:52.882</payment_date>
<payment_mode>ELNPAY4</payment_mode>
<paymentFee>5000</paymentFee>
<tob>500.0</tob>
<collector>QRTGH78</collector>
<cashier>null</cashier>
</bill>
</ns3:response>/})
=end
    @order_id = (response.xpath('//ns3:response').at('bill').at('number').content rescue nil)
    @amount = (response.xpath('//ns3:response').at('bill').at('amount').content rescue nil)
    @payment_fee = (response.xpath('//ns3:response').at('bill').at('paymentFee').content rescue nil)
    @tob = (response.xpath('//ns3:response').at('bill').at('tob').content rescue nil)

    if valid_guce_params?
      new_transaction_amount = @amount.to_f.round(2)
      if new_transaction_amount != session[:trs_amount]
        @guce_notice = "Le montant de la transaction a changé. Il est passé de: #{session[:trs_amount]} #{session[:currency].symbol} à #{new_transaction_amount} #{session[:currency].symbol}"
      end
      session[:trs_amount] = new_transaction_amount
      session[:basket]['transaction_amount'] = new_transaction_amount
      @shipping = @payment_fee.to_i + @tob.to_i

    else
      redirect_to error_page_path
    end
  end

  # Make sure the order id is not null and amount is a number
  def valid_guce_params?
    if @order_id == nil || @amount == nil || not_a_number?(@amount) || @payment_fee == nil || not_a_number?(@payment_fee) || @tob == nil || not_a_number?(@tob)
      return false
    else
      return true
    end
  end

  def guce_request_payment?(authentication_token, collector_id, payment_mode)
    parameters = Parameter.first

    if authentication_token == '57813dc7992fbdc721ca5f6b0d02d559'
      OmLog.create(log_rl: "Requete au GUCE: " + "#{parameters.guce_payment_url}/GPG_GUCE/rest/Mob_Mon_Pay/pay/#{@basket.number}/#{@basket.original_transaction_amount}/#{payment_mode}/#{collector_id}/#{(@basket.login_id.blank? ? 'NULL' : @basket.login_id)}")
      request = Typhoeus::Request.new("#{parameters.guce_payment_url}/GPG_GUCE/rest/Mob_Mon_Pay/pay/#{@basket.number}/#{@basket.original_transaction_amount}/#{payment_mode}/#{collector_id}/#{(@basket.login_id.blank? ? 'NULL' : @basket.login_id)}", method: :get, followlocation: true)
      request.run

      response = (Nokogiri.XML(request.response.body) rescue nil)

      OmLog.create(log_rl: "Reponse du GUCE: " + (request.response.body.to_s rescue ""))
      status = (response.xpath('//ns2:result').text rescue nil)

      case status
        when '0'
          @status_id = '1'
        when '1'
          @status_id = '2'
        when nil
          @status_id = 3
        end
    end
  end

end
