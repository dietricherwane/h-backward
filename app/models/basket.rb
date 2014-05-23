class Basket < ActiveRecord::Base
  belongs_to :service
  belongs_to :operation
  attr_accessible :number, :service_id, :payment_status, :notified_to_ecommerce, :operation_id, :transaction_id, :transaction_amount, :notified_to_back_office
end
