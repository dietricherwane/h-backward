class Novapay < ActiveRecord::Base
  belongs_to :service
  belongs_to :operation
  belongs_to :currency

  attr_accessible :number, :service_id, :payment_status, :operation_id, :transaction_amount, :notified_to_back_office, :transaction_id, :fees, :currency_id, :paid_transaction_amount, :paid_currency_id, :rate, :conflictual_transaction_amount, :conflictual_currency, :compensation_rate, :created_at, :original_transaction_amount, :refoper, :login_id, :paymoney_account_number, :paymoney_account_token, :paymoney_reload_request, :paymoney_reload_response, :paymoney_token_request, :paymoney_transaction_id
end
