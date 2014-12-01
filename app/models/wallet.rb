class Wallet < ActiveRecord::Base
  # Accessible fields
  attr_accessible :name, :country_id, :url, :logo, :published, :authentication_token, :currency, :currency_amount, :currency_id, :fee, :percentage, :logo, :published, :table_name

  # Paperclip config
  has_attached_file :logo, :styles => { :medium => "200x200>", :thumb => "100x100>" }, :default_url => "/images/:style/missing.png"
  validates_attachment_content_type :logo, :content_type => /\Aimage\/.*\Z/

  # Relationships
  belongs_to :currency
  belongs_to :country
  has_many :available_wallets
  has_many :services, through: :available_wallets
end
