class AddPaymoneyPasswordToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :paymoney_password, :string
  end
end
