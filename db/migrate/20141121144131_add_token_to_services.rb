class AddTokenToServices < ActiveRecord::Migration
  def change
    add_column :services, :token, :string, limit: 100
  end
end
