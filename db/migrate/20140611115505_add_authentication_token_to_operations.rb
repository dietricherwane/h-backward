class AddAuthenticationTokenToOperations < ActiveRecord::Migration
  def change
    add_column :operations, :authentication_token, :string
  end
end
