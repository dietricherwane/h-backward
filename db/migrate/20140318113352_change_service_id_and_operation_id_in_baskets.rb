class ChangeServiceIdAndOperationIdInBaskets < ActiveRecord::Migration
  def change
    change_column :baskets, :service_id, :string
    change_column :baskets, :operation_id, :string
  end
end
