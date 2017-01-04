class AddCurrencyIdToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :currency_id, :integer
  end
end
