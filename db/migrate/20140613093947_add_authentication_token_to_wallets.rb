class AddAuthenticationTokenToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :authentication_token, :string
  end
end
