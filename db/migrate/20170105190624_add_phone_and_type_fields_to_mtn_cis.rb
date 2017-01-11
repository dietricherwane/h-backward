class AddPhoneAndTypeFieldsToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :phone_number, :string
    add_column :mtn_cis, :type_token, :string
  end
end
