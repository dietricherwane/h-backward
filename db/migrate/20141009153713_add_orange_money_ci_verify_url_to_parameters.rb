class AddOrangeMoneyCiVerifyUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :orange_money_ci_verify_url, :string
  end
end
