class PaypalController < ApplicationController

  before_action :only => :guard do |s| s.get_service(params[:service_id], params[:operation_id], params[:basket_number], params[:transaction_amount]) end
  before_action :only => :guard do |o| o.filter_connections params[:operation_id] end
  before_action :only => :guard do |s| s.paypal_basket_already_paid?(params[:basket_number]) end

  layout "paypal"
  
  def guard
    redirect_to action: "index"
  end  
  
  def index
    @shipping = ((session[:service]["transaction_amount"]).to_f * 0.02).round(2)
    PaypalBasket.create(:number => session[:service]["basket_number"], :service_id => session[:service_id], :operation_id => session[:service]["operation_id"], :transaction_amount => session[:service]["transaction_amount"])
  end
  
  def payment_result_listener
    @request = Typhoeus::Request.new("https://www.sandbox.paypal.com/cgi-bin/webscr", method: :post, params: {cmd: "_notify-sync", tx: "#{params[:tx]}", at: "wc9rbATkeBqy488jdxnQeXHsv9ya8Sh6Pq_DST3BihQ4oV2-De3epJilfKG"})
    @request.run
    @response = @request.response
    Hub.create(:server_response => "params => #{params[:tx]} #{params[:st]}")
    if(params[:st] == "Completed")
      @basket = PaypalBasket.find_by_number(params[:cm].to_s)
      if(!@basket.blank?)
        @basket.update_attributes(:payment_status => true)
        redirect_to success_page_path
        #redirect_to "www.wimboo.com/paypal/#{params[:cm]}/1/#{params[:amt]}"
        # envoyer vers le site marchand une requête avec certains paramètres
      end
    else
      redirect_to error_page_path
      #redirect_to "www.wimboo.com/paypal/#{params[:cm]}/0/#{params[:amt]}"
    end    
  end
    
  end
  
  def paypal_display
    @params = params
  end

end
