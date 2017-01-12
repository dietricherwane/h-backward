class AddPaymoneyWalletUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :paymoney_wallet_url, :string
  end
end
