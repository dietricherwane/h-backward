class AddCollectorIdToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :collector_id, :string
  end
end
