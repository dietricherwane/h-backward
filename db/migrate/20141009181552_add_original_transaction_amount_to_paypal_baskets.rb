class AddOriginalTransactionAmountToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :original_transaction_amount, :string
  end
end
