class AddOriginalTransactionAmountToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :original_transaction_amount, :string
  end
end
