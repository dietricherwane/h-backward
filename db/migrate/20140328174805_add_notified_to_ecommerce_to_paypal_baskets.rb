class AddNotifiedToEcommerceToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :notified_to_ecommerce, :boolean
  end
end
