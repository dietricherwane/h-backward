class AddFeesToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :fees, :float
  end
end
