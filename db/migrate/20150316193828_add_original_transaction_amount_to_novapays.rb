class AddOriginalTransactionAmountToNovapays < ActiveRecord::Migration
  def change
    add_column :novapays, :original_transaction_amount, :float
  end
end
