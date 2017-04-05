class AddOriginalTransactionAmountToOrangeMoneyCiBaskets < ActiveRecord::Migration
  def change
    add_column :orange_money_ci_baskets, :original_transaction_amount, :string
  end
end
