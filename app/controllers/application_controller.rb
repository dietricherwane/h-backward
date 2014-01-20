class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session#:exception
  
  def get_service(service_id, operation_id, basket_number, transaction_amount)
    # check if transaction_amount is a number
    session[:service] = case service_id
      when "Ws001" then {"id" => "Ws001", "basket_number" => "#{basket_number}", "operation_id" => "#{operation_id}", "transaction_amount" => "#{transaction_amount}", "operations" => {"1" => {"title" => "Effectuer un achat.", "title_comment" => "Achat de musiques."}, "2" => {"title" => "Effectuer un abonnement.", "title_comment" => "S'abonner et bénéficier de nombreux avantages."}}, "name" => "Wimboo", "logo_css_class" => "wimboo_logo", "return_url" => "http://wimboo.com/payment/success/", "transaction_status" => ""}
      when "Ws002" then {"id" => "Ws002", "basket_number" => "#{basket_number}", "operation_id" => "#{operation_id}", "transaction_amount" => "#{transaction_amount}", "operations" => {"1" => {"title" => "Effectuer un achat.", "title_comment" => "Achat de journaux."}}, "name" => "E-kiosk", "logo_css_class" => "e-kiosk_logo", "return_url" => "http://wimboo.com/payment/success/", "transaction_status" => ""}
      else {}
    end
  end
  
  def filter_connections(operation_id)
    if session[:service].blank? or session[:service]["operations"]["#{operation_id}"].nil?
      redirect_to error_page_path
    end
  end
  
  def basket_already_paid?(basket_number)
    @service = Service.find_by_code(session[:service]["id"])
    @basket = @service.baskets.where("number = '#{basket_number.to_i}' AND operation_id = #{session[:service]["operation_id"].to_i}")#find_by_number(basket_number.to_i)
    session[:service_id] = @service.id
    if !@basket.empty? and @basket.first.payment_status.eql?(true)
      redirect_to error_page_path
    end
  end
  
  def generate_url(url, params = {})
    uri = URI(url)
    uri.query = params.to_query
    uri.to_s
  end
  
  def run_typhoeus_request(request, code_on_success)
    request.on_complete do |response|
      if response.success?
        eval(code_on_success)         
      elsif response.timed_out?
        @error_messages << "Délai d'attente de la demande dépassé. Veuillez contacter l'administrateur."
        @error = true
      elsif response.code == 0
        @error_messages << "L'URL demandé n'existe pas. Veuillez contacter l'administrateur."
        @error = true
      else
        @error_messages << "Une erreur s'est produite. Veuillez contacter l'administrateur"
        @error = true
      end      
    end
    
    hydra = Typhoeus::Hydra.hydra
	  hydra.queue(request)
	  hydra.run	
  end
  
end
