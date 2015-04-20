class AddFeesToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :fees, :float
  end
end
