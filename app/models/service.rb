class Service < ActiveRecord::Base
  has_many :baskets
  attr_accessible :code, :name
end
