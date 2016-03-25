class AddNotifiedToEcommerceToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :notified_to_ecommerce, :string
  end
end
