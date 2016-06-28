class AddPaymoneyFieldsToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :paymoney_account_number, :text
    add_column :paypal_baskets, :paymoney_account_token, :string
    add_column :paypal_baskets, :paymoney_reload_request, :text
    add_column :paypal_baskets, :paymoney_reload_response, :text
    add_column :paypal_baskets, :paymoney_token_request, :text
    add_column :paypal_baskets, :paymoney_transaction_id, :string
  end
end
