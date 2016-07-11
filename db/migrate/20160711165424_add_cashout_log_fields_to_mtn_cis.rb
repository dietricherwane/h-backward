class AddCashoutLogFieldsToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :cashout_account_number, :string
    add_column :mtn_cis, :cashout_notified_to_front_office, :boolean
    add_column :mtn_cis, :cashout_notification_request, :text
    add_column :mtn_cis, :cashout_notification_response, :text
  end
end
