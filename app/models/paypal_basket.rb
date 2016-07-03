class PaypalBasket < ActiveRecord::Base
  belongs_to :service
  belongs_to :operation
  belongs_to :currency

  attr_accessible :number, :fees, :rate, :service_id, :notified_to_ecommerce, :conflictual_transaction_amount, :conflictual_currency, :payment_status, :paid_transaction_amount, :paid_currency_id, :operation_id, :currency_id, :transaction_id, :transaction_amount, :notified_to_back_office, :original_transaction_amount, :login_id, :paymoney_account_number, :paymoney_account_token, :paymoney_reload_request, :paymoney_reload_response, :paymoney_token_request, :paymoney_transaction_id, :cashout, :cashout_completed, :paymoney_password

end
