class AddCompensationRateToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :compensation_rate, :float
  end
end
