class AddEnabledToPaymentWayFees < ActiveRecord::Migration
  def change
    add_column :payment_way_fees, :enabled, :boolean
  end
end
