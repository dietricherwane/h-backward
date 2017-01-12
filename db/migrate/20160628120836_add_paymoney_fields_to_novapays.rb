class AddPaymoneyFieldsToNovapays < ActiveRecord::Migration
  def change
    add_column :novapays, :paymoney_account_number, :text
    add_column :novapays, :paymoney_account_token, :string
    add_column :novapays, :paymoney_reload_request, :text
    add_column :novapays, :paymoney_reload_response, :text
    add_column :novapays, :paymoney_token_request, :text
    add_column :novapays, :paymoney_transaction_id, :string
  end
end
