class AddPaymoneyUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :paymoney_url, :string
  end
end
