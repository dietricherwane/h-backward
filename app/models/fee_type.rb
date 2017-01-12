class FeeType < ActiveRecord::Base
  # accessible fields
  attr_accessible :name, :token

  # Relationships
  has_many :fees
end
