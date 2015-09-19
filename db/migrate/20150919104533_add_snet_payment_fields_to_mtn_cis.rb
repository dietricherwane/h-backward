class AddSnetPaymentFieldsToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :snet_payment_response, :text
    add_column :mtn_cis, :snet_payment_error_response, :text
  end
end
