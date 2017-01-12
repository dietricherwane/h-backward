class AddPaymoneyFieldsToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :paymoney_account_number, :text
    add_column :mtn_cis, :paymoney_account_token, :string
    add_column :mtn_cis, :paymoney_reload_request, :text
    add_column :mtn_cis, :paymoney_reload_response, :text
    add_column :mtn_cis, :paymoney_token_request, :text
    add_column :mtn_cis, :paymoney_transaction_id, :string
  end
end
