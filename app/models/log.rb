class Log < ActiveRecord::Base
  # Accessible fields
  attr_accessible :description, :sent_request, :sent_response, :paymoney_account_number, :paymoney_token_request, :paymoney_token_response
end
