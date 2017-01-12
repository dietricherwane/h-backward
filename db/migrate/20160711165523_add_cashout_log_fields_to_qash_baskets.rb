class AddCashoutLogFieldsToQashBaskets < ActiveRecord::Migration
  def change
    add_column :qash_baskets, :cashout_account_number, :string
    add_column :qash_baskets, :cashout_notified_to_front_office, :boolean
    add_column :qash_baskets, :cashout_notification_request, :text
    add_column :qash_baskets, :cashout_notification_response, :text
  end
end
