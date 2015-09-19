class AddOrangeMoneyCiUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :orange_money_ci_initialization_url, :string
    add_column :parameters, :orange_money_ci_url, :string
  end
end
