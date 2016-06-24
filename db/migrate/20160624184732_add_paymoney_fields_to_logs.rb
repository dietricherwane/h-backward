class AddPaymoneyFieldsToLogs < ActiveRecord::Migration
  def change
    add_column :logs, :paymoney_token_request, :text
    add_column :logs, :paymoney_token_response, :text
  end
end
