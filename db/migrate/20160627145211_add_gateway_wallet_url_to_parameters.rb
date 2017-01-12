class AddGatewayWalletUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :gateway_wallet_url, :string
  end
end
