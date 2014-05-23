class AddNotifiedToEcommerceToDelayedPayments < ActiveRecord::Migration
  def change
    add_column :delayed_payments, :notified_to_ecommerce, :boolean
  end
end
