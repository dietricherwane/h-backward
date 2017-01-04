class AddTimestampToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :created_at, :datetime
    add_column :mtn_cis, :updated_at, :datetime
  end
end
