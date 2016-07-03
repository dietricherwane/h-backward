class AddCashoutFieldsToUbas < ActiveRecord::Migration
  def change
    add_column :ubas, :cashout, :boolean
    add_column :ubas, :cashout_completed, :boolean
    add_column :ubas, :paymoney_password, :string
  end
end
