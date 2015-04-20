class Currency < ActiveRecord::Base
  has_many :wallets
  has_many :baskets
  has_many :paypal_baskets
  has_many :orange_money_ci_baskets
  has_many :qash_baskets
  attr_accessible :name, :code, :symbol, :published
end
