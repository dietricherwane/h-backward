class AddCurrencyIdToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :currency_id, :integer
  end
end
