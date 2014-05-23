class AddNotifiedToEcommerceToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :notified_to_ecommerce, :boolean
  end
end
