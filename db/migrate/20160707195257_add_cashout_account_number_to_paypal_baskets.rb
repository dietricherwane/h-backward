class AddCashoutAccountNumberToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :cashout_account_number, :string
    add_column :paypal_baskets, :cashout_notified_to_front_office, :boolean
  end
end
