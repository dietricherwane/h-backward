class ChangeServiceIdAndOperationIdInDelayedPaymentsBaskets < ActiveRecord::Migration
  def change
    change_column :delayed_payments, :service_id, :string
    change_column :delayed_payments, :operation_id, :string
  end
end
