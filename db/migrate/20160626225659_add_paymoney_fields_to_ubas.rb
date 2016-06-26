class AddPaymoneyFieldsToUbas < ActiveRecord::Migration
  def change
    add_column :ubas, :paymoney_account_number, :text
    add_column :ubas, :paymoney_account_token, :string
    add_column :ubas, :paymoney_reload_request, :text
    add_column :ubas, :paymoney_reload_response, :text
    add_column :ubas, :paymoney_token_request, :text
  end
end
