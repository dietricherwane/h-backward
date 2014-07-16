class ErrorsHandlingController < ApplicationController

  layout "errors_success"

  def error_page
    @title = "Erreur"
  end
  
  def success_page
    @title = "Succès"
  end

  def home_page
    redirect_to "http://37.59.18.41:3759"
  end
end
