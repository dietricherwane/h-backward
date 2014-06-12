class AddPublishedToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :published, :boolean
  end
end
