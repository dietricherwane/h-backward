class AddOmpayTokenToOrangeMoneyCiBaskets < ActiveRecord::Migration
  def change
    add_column :orange_money_ci_baskets, :ompay_token, :string
  end
end
