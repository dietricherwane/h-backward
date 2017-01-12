class AddCashoutLogFieldsToNovapays < ActiveRecord::Migration
  def change
    add_column :novapays, :cashout_account_number, :string
    add_column :novapays, :cashout_notified_to_front_office, :boolean
    add_column :novapays, :cashout_notification_request, :text
    add_column :novapays, :cashout_notification_response, :text
  end
end
