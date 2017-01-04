class AddRateToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :rate, :float
  end
end
