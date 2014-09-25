class Service < ActiveRecord::Base
  has_many :baskets
  has_many :paypal_baskets
  has_many :orange_money_ci_baskets
  has_many :delayed_payments
  has_many:operations
  attr_accessible :code, :name, :sales_area, :comment, :url_on_success, :url_to_ipn, :url_on_error, :url_on_basket_already_paid, :url_on_session_expired, :url_on_hold_success, :url_on_hold_error, :url_on_hold_listener, :authentication_token, :published
  #validates :code, :name, :sales_area, :comment, :presence => true
end
