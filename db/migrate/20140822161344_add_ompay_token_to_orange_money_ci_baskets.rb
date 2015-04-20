class AddOmpayTokenToOrangeMoneyCiBaskets < ActiveRecord::Migration
  def change
    add_column :orange_money_ci_baskets, :ompay_token, :string
    add_column :orange_money_ci_baskets, :ompay_clientid, :string
    add_column :orange_money_ci_baskets, :ompay_cname, :string
    add_column :orange_money_ci_baskets, :ompay_payid, :string
    add_column :orange_money_ci_baskets, :ompay_date, :string
    add_column :orange_money_ci_baskets, :ompay_time, :string
    add_column :orange_money_ci_baskets, :ompay_ipaddr, :string
    add_column :orange_money_ci_baskets, :ompay_signature, :string
  end
end
