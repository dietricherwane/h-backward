class AddTableNameToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :table_name, :string, limit: 100
  end
end
