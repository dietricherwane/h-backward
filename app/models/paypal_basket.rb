class PaypalBasket < ActiveRecord::Base
  belongs_to :service
  attr_accessible :number, :service_id, :payment_status, :operation_id, :transaction_amount
end
