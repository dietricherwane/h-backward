class AddConflictualTransactionAmountAndConflictualCurrencyToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :conflictual_transaction_amout, :float
    add_column :baskets, :conflictual_currency, :string, limit: 3
  end
end
