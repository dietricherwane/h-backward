class AddCurrencyAndCurrencyAmountToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :currency, :string
    add_column :wallets, :currency_amount, :float
  end
end
