class AddTransactionIdToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :transaction_id, :string
  end
end
