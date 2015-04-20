class AddQuashTransactionIdToQashBaskets < ActiveRecord::Migration
  def change
    add_column :qash_baskets, :qash_transaction_id, :string
  end
end
