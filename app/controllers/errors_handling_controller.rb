class ErrorsHandlingController < ApplicationController

  layout "errors_success"

  def error_page
    @title = "Erreur"
  end
  
  def success_page
    @title = "Succès"
  end

end
