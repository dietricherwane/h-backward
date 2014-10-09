class Operation < ActiveRecord::Base
  belongs_to :service
  has_many :baskets
  has_many :paypal_baskets
  has_many :orange_money_ci_baskets
  has_many :qash_baskets
  has_many :delayed_payments
  attr_accessible :code, :name, :comment, :service_id, :published, :authentication_token
end
