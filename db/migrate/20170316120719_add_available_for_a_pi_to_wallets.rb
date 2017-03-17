class AddAvailableForAPiToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :available_for_api, :boolean, default: false
  end
end
