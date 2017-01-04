class AddWalletIdToPaymentWayFees < ActiveRecord::Migration
  def change
    add_column :payment_way_fees, :wallet_id, :integer
  end
end
