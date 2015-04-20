class AddPublishedToPaymentWayFees < ActiveRecord::Migration
  def change
    add_column :payment_way_fees, :published, :boolean
  end
end
