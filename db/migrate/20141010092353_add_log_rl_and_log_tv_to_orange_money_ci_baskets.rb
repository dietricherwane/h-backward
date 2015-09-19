class AddLogRlAndLogTvToOrangeMoneyCiBaskets < ActiveRecord::Migration
  def change
    add_column :orange_money_ci_baskets, :log_rl, :text
    add_column :orange_money_ci_baskets, :log_tv, :text
  end
end
