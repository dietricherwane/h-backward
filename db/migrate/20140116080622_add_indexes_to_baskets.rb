class AddIndexesToBaskets < ActiveRecord::Migration
  def change
    add_index :baskets, :service_id
    add_index :baskets, :number
    add_index :baskets, :operation_id
  end
end
