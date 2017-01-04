class RemoveCurrencyAndCurrencyAmountFromWallets < ActiveRecord::Migration
  def change
    remove_column :wallets, :currency
    remove_column :wallets, :currency_amount
  end
end
