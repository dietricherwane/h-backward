class Log < ActiveRecord::Base
  # Accessible fields
  attr_accessible :description, :sent_request, :sent_response, :paymoney_account_number
end
