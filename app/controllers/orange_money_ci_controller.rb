class OrangeMoneyCiController < ApplicationController

  def payment_result_listener
    render text: params.except(:controller, :action)
  end
  
  def ipn
    render text: params.except(:controller, :action)
  end
end
