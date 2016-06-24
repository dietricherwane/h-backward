class Service < ActiveRecord::Base
  # Accessible fields
  attr_accessible :code, :name, :sales_area, :comment, :url_on_success, :url_to_ipn, :url_on_error, :url_on_basket_already_paid, :url_on_session_expired, :url_on_hold_success, :url_on_hold_error, :url_on_hold_listener, :authentication_token, :published, :logo, :token, :ecommerce_profile_id

  # Paperclip config
  has_attached_file :logo, :styles => { :medium => "200x200>", :thumb => "100x100>" }, :default_url => "/images/:style/missing.png"
  validates_attachment_content_type :logo, :content_type => /\Aimage\/.*\Z/
  validates :ecommerce_profile_id, presence: true

  # Relationships
  has_many :baskets
  has_many :paypal_baskets
  has_many :mtn_cis
  has_many :orange_money_ci_baskets
  has_many :qash_baskets
  has_many :novapays
  has_many :ubas
  has_many :delayed_payments
  has_many :operations
  has_many :available_wallets
  has_many :wallets, through: :available_wallets
  belongs_to :ecommerce_profile

  #validates :code, :name, :sales_area, :comment, :presence => true
end
