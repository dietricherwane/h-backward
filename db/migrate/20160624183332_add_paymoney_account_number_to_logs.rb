class AddPaymoneyAccountNumberToLogs < ActiveRecord::Migration
  def change
    add_column :logs, :paymoney_account_number, :string
  end
end
