class ChangeNumberTypeInBaskets < ActiveRecord::Migration
  def self.up
    change_column :baskets, :number, :string
  end
end
