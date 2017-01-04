class Country < ActiveRecord::Base
  # Accessible fields
  attr_accessible :name, :published, :code

  # Relatinships
  has_many :wallets

  def default_country
    "International"
  end
end
