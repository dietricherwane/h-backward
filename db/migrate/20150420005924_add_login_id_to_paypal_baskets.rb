class AddLoginIdToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :login_id, :string
  end
end
