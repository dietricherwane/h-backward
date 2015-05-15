class RemoveLogoFromWallets < ActiveRecord::Migration
  def change
    remove_column :wallets, :logo
  end
end
