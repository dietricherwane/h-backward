class AddWalletUsedToAvailableWallets < ActiveRecord::Migration
  def change
    add_column :available_wallets, :wallet_used, :boolean
  end
end
