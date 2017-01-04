class AddPaymentStatusToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :payment_status, :boolean
  end
end
