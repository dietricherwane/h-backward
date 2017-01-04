class AddOriginalTransactionAmountToQashBaskets < ActiveRecord::Migration
  def change
    add_column :qash_baskets, :original_transaction_amount, :string
  end
end
