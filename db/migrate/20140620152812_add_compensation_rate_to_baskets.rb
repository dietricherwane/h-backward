class AddCompensationRateToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :compensation_rate, :float
  end
end
