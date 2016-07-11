class AddCashoutLogFieldsToUbas < ActiveRecord::Migration
  def change
    add_column :ubas, :cashout_account_number, :string
    add_column :ubas, :cashout_notified_to_front_office, :boolean
    add_column :ubas, :cashout_notification_request, :text
    add_column :ubas, :cashout_notification_response, :text
  end
end
