class AddNumberToUbas < ActiveRecord::Migration
  def change
    add_column :ubas, :number, :string
    remove_column :ubas, :order_id
  end
end
