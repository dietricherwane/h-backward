class AddCashoutNotificationsToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :cashout_notification_request, :text
    add_column :paypal_baskets, :cashout_notification_response, :text
  end
end
