class PaymentWayFee < ActiveRecord::Base
  attr_accessible :name, :fee, :percentage, :code
end
