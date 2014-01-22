class Service < ActiveRecord::Base
  has_many :baskets
  has_many :paypal_baskets
  attr_accessible :code, :name
end
