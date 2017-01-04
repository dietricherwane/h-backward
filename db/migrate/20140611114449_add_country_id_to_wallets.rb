class AddCountryIdToWallets < ActiveRecord::Migration
  def change
    add_column :wallets, :country_id, :integer
  end
end
