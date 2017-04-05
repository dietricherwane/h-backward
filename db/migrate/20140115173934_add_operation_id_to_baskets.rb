class AddOperationIdToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :operation_id, :integer
  end
end
