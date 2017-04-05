class AddAliasToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :alias, :string
  end
end
