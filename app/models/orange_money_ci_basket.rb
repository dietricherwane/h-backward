class OrangeMoneyCiBasket < ActiveRecord::Base
  belongs_to :service
  belongs_to :operation
  belongs_to :currency
  attr_accessible :number, :service_id, :payment_status, :operation_id, :transaction_amount, :notified_to_back_office, :transaction_id, :fees, :currency_id, :paid_transaction_amount, :paid_currency_id, :rate, :conflictual_transaction_amount, :conflictual_currency, :compensation_rate, :created_at, :ompay_token, :ompay_client_id, :ompay_cnmae, :ompay_id, :ompay_date, :ompay_time, :ompay_ipaddr, :ompay_signature, :original_transaction_amount
end
