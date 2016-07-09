class Fee < ActiveRecord::Base
  # accessible fields
  attr_accessible :fee_type_id, :min_value, :max_value, :fee_value
end
