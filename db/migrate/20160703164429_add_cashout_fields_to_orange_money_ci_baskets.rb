class AddCashoutFieldsToOrangeMoneyCiBaskets < ActiveRecord::Migration
  def change
    add_column :orange_money_ci_baskets, :cashout, :boolean
    add_column :orange_money_ci_baskets, :cashout_completed, :boolean
    add_column :orange_money_ci_baskets, :paymoney_password, :string
  end
end
