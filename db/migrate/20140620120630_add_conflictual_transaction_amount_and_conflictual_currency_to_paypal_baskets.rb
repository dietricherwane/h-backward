class AddConflictualTransactionAmountAndConflictualCurrencyToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :conflictual_transaction_amout, :float
    add_column :paypal_baskets, :conflictual_currency, :string, limit: 3
  end
end
