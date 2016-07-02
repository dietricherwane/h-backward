class AddCashoutFieldsToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :cashout, :boolean
    add_column :paypal_baskets, :cashout_completed, :boolean
  end
end
