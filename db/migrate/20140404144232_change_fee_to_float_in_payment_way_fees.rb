class ChangeFeeToFloatInPaymentWayFees < ActiveRecord::Migration
  def change
    change_column :payment_way_fees, :fee, :float
  end
end
