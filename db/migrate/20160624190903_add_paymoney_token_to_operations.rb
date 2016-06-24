class AddPaymoneyTokenToOperations < ActiveRecord::Migration
  def change
    add_column :operations, :paymoney_token, :string
  end
end
