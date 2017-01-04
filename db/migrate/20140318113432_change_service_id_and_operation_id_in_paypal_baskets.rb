class ChangeServiceIdAndOperationIdInPaypalBaskets < ActiveRecord::Migration
  def change
    change_column :paypal_baskets, :service_id, :string
    change_column :paypal_baskets, :operation_id, :string
  end
end
