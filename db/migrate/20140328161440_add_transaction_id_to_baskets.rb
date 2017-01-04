class AddTransactionIdToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :transaction_id, :string
  end
end
