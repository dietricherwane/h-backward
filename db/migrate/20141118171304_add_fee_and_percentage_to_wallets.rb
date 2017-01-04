class AddFeeAndPercentageToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :fee, :float
    add_column :wallets, :percentage, :boolean
  end
end
