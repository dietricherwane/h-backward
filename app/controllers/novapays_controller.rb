require 'net/http'

class NovapaysController < ApplicationController
  @@second_origin_url = Parameter.first.second_origin_url

  ##before_action :only => :guard do |o| o.filter_connections end
  before_action :session_exists?, :except => [:ipn, :transaction_acknowledgement, :payment_result_listener, :valid_result_parameters]
  # Si l'utilisateur ne s'est pas connecté en passant par main#guard, on le rejette
  before_action :except => [:ipn, :transaction_acknowledgement, :payment_result_listener, :valid_result_parameters] do |s| s.session_authenticated? end

  # Set transaction amount for GUCE requests
  before_action :only => :index do |o| o.guce_request? end

  layout :select_layout

  def select_layout
    if session[:service].authentication_token == '57813dc7992fbdc721ca5f6b0d02d559'
      return "guce"
    else
      return "novapay"
    end
  end

  # Reçoit les requêtes venant des différents services
  def guard
    redirect_to action: "index"
  end

  def index
    initialize_customer_view("77e26b3cbd", "ceiled_transaction_amount", "ceiled_shipping_fee")
    #get_service_logo(session[:service].token)

    # vérifie qu'un numéro panier appartenant à ce service n'existe pas déjà. Si non, on crée un panier temporaire, si oui, on met à jour le montant envoyé par le ecommerce, la monnaie envoyée par celui ci ainsi que le montant, la monnaie et les frais à envoyer au ecommerce
    @basket = Novapay.where("number = '#{session[:basket]["basket_number"]}' AND service_id = '#{session[:service].id}' AND operation_id = '#{session[:operation].id}'")
    if @basket.blank?
      @basket = Novapay.create(:number => session[:basket]["basket_number"], :service_id => session[:service].id, :operation_id => session[:operation].id, :original_transaction_amount => session[:trs_amount], :transaction_amount => session[:trs_amount].to_f.ceil, :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, transaction_id: Time.now.strftime("%Y%m%d%H%M%S%L"), :fees => @shipping, :rate => @rate, :login_id => session[:login_id])
    else
      @basket.first.update_attributes(:transaction_amount => session[:trs_amount].to_f.ceil, :original_transaction_amount => session[:trs_amount], :currency_id => session[:currency].id, :paid_transaction_amount => @transaction_amount, :paid_currency_id => @wallet_currency.id, :fees => @shipping, :rate => @rate, :login_id => session[:login_id])
    end
  end

  # Redirect to NovaPay platform
  def process_payment
    OmLog.create(log_rl: %Q[_identify=3155832361,_password=#{Digest::MD5.hexdigest('3155832361' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '44680')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')}])
    request = Typhoeus::Request.new("https://novaplus.ci/NOVAPAY_WEB/FR/novapay.awp", method: :post, body: %Q[{"_descprod": "#{session[:service].name}", "_refact": "#{params[:_refact]}", "_prix": "#{params[:_prix]}" }], headers: { 'QUERY_STRING' => %Q[_identify=3155832361,_password=#{Digest::MD5.hexdigest('3155832361' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '44680')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')}], followlocation: true })
    #, params: { _refact: params[:_refact], _prix: params[:_prix], _descprod: "#{session[:service].name}" }
    request.run
    response = request.response

    render text: response.body
  end

  def payment_result_listener
    @refact = params[:refac].strip
    @refoper = params[:refoper].strip
    @status = params[:status].strip
    @mtnt = params[:mtnt].strip
    OmLog.create(log_rl: params.to_s + "method: #{request.get? ? 'GET' : 'POST'}") rescue nil
    @request_type = request
    #valid_transaction
    if valid_result_parameters
      if valid_transaction || request.get?
        @basket = Novapay.find_by_transaction_id(@refact)
        if @basket

          # Use NovaPay authentication_token
          update_wallet_used(@basket, "77e26b3cbd")
          request.post? ? @status = "1" : nil
          if (@status.to_s.downcase.strip == "1" || @status.to_s.downcase.strip == "succes")

            # Conversion du montant débité par le wallet et des frais en euro avant envoi pour notification au back office du hub
            @rate = get_change_rate("XAF", "EUR")
            if request.post?
              @basket.update_attributes(payment_status: true, refoper: @refoper, compensation_rate: @rate)
            end
            @amount_for_compensation = ((@basket.paid_transaction_amount + @basket.fees) * @rate).round(2)
            @fees_for_compensation = (@basket.fees * @rate).round(2)

            if request.post?
              # Notification au back office du hub
              notify_to_back_office(@basket, "#{@@second_origin_url}/GATEWAY/rest/WS/#{@basket.operation.id}/#{@basket.number}/#{@basket.transaction_id}/#{@amount_for_compensation}/#{@fees_for_compensation}/2")

              # Update in available_wallet the number of successful_transactions
              update_number_of_succeed_transactions
              # Handle GUCE notifications
              guce_request_payment?(@basket.service.authentication_token, 'QRTGH78', 'VIECOB8')
              render text: "0"
            else
              # Redirection vers le site marchand
              redirect_to "#{@basket.service.url_on_success}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=1&wallet=biao&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=#{@basket.paid_transaction_amount}&paid_currency=#{Currency.find_by_id(@basket.paid_currency_id).code}&change_rate=#{@basket.rate}&id=#{@basket.login_id}"
            end
          else
            if request.post?
              @basket.update_attributes(payment_status: false, refoper: @refoper)

              # Update in available_wallet the number of failed_transactions
              update_number_of_failed_transactions
              render text: "1"
            else
              redirect_to "#{@basket.service.url_on_error}?transaction_id=#{@basket.transaction_id}&order_id=#{@basket.number}&status_id=0&wallet=biao&transaction_amount=#{@basket.original_transaction_amount}&currency=#{@basket.currency.code}&paid_transaction_amount=&paid_currency=&change_rate=#{@basket.rate}&conflictual_transaction_amount=#{@basket.conflictual_transaction_amount}&conflictual_currency=#{@basket.conflictual_currency}&id=#{@basket.login_id}"
            end
          end
        else
          if request.post?
            render text: "2"#"order id not found" + @refac
          else
            #redirect_to error_page_path
            render text: "order id not found" + @refac
          end
        end
      else
        if request.post?
          render text: "3"#"transaction non trouvée: " + @result
        else
          #redirect_to error_page_path
          render text: "transaction non trouvée: " + @result
        end
      end
    else
      if request.post?
        render text: "4"#"invalid parameters" + params.to_s
      else
        #redirect_to error_page_path
        render text: "invalid parameters" + params.to_s
      end
    end
  end

  def valid_result_parameters
    if !@refact.blank? && !@refoper.blank? && !@status.blank?
      return true
    else
      return false
    end
  end

  def ipn
    render text: params.except(:controller, :action)
  end

  def valid_transaction
    if @request_type.post?
    #OmLog.create(log_rl: %Q[_identify=3155832361,_password=#{Digest::MD5.hexdigest('3155832361' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '44680')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')}])
    request = Typhoeus::Request.new("https://novaplus.ci/NOVAPAY_WEB/FR/paycheck.awp", method: :post, body: %Q[{"_refact": "#{@refact}", "_prix": "#{@mtnt}", "_nooper": "#{@refoper}" }], headers: { 'QUERY_STRING' => %Q[_identify=3155832361,_password=#{Digest::MD5.hexdigest('3155832361' + DateTime.now.strftime('%Y%m%d%H%M%S%L') + '44680')},_dateheure=#{DateTime.now.strftime('%Y%m%d%H%M%S%L')}]}, followlocation: true, method: :get)
    @result = nil

    request.on_complete do |response|
      if response.success?
        @result = response.body.strip
      end
    end

    request.run

<<<<<<< HEAD
    OmLog.create(log_rl: "Paramètres de vérification de paiement: " + @result.to_s)
=======
    #OmLog.create(log_rl: "Paramètres de vérification de paiement: " + @result.to_s)
>>>>>>> ebc0cd2998237ac51c9edbbd4fc405c01e0b40d7

    !@result.blank? ? true : false
    end
  end

  def notify_to_back_office(basket, url)
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

  # Returns 0 or 1 depending on the status of the transaction
  def transaction_acknowledgement
    generic_transaction_acknowledgement(Novapay, params[:transaction_id])
  end

end
