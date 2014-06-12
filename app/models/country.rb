class Country < ActiveRecord::Base
  attr_accessible :name, :published
  
  def default_country
    "International"
  end
end
