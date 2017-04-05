class AddNotifiedToBackOfficeToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :notified_to_back_office, :boolean
  end
end
