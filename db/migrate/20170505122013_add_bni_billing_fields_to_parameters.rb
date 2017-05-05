class AddBniBillingFieldsToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :bni_billing_request, :string
    add_column :parameters, :bni_billing_username, :string
    add_column :parameters, :bni_billing_password, :string
    add_column :parameters, :bni_operator_id, :string
    add_column :parameters, :bni_channel_id, :string
  end
end
