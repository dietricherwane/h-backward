class AddCashoutFieldsToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :cashout, :boolean
    add_column :mtn_cis, :cashout_completed, :boolean
    add_column :mtn_cis, :paymoney_password, :string
  end
end
