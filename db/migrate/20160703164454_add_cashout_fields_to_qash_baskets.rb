class AddCashoutFieldsToQashBaskets < ActiveRecord::Migration
  def change
    add_column :qash_baskets, :cashout, :boolean
    add_column :qash_baskets, :cashout_completed, :boolean
    add_column :qash_baskets, :paymoney_password, :string
  end
end
