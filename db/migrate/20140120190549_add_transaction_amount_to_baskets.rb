class AddTransactionAmountToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :transaction_amount, :float
  end
end
