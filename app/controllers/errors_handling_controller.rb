class ErrorsHandlingController < ApplicationController

  layout "errors_success"

  def error_page
    @title = "Erreur"
  end
  
  def success_page
    @title = "Succès"
  end

  def home_page
    #redirect_to "http://pay-money.net"
    render :file => "#{Rails.root}/public/404.html", :status => 404, :layout => false
  end
end
