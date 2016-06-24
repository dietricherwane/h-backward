class EcommerceProfile < ActiveRecord::Base
  # Accessible fields
  attr_accessible :description, :token, :published

  # Relationships
  has_many :services
end
