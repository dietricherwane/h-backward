class Wallet < ActiveRecord::Base
  attr_accessible :name, :country_id, :url, :logo, :published, :authentication_token, :currency, :currency_amount, :currency_id
  belongs_to :currency
end
