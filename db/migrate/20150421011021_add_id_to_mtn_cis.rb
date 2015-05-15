class AddIdToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :id, :primary_key
  end
end
