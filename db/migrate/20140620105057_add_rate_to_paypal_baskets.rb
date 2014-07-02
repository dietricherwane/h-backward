class AddRateToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :rate, :float
  end
end
