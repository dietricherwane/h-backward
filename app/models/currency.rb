class Currency < ActiveRecord::Base
  has_many :wallets
  has_many :baskets
  has_many :paypal_baskets
  attr_accessible :name, :code, :symbol, :published
end
