class AddEcommerceProfileIdToServices < ActiveRecord::Migration
  def change
    add_column :services, :ecommerce_profile_id, :integer
  end
end
