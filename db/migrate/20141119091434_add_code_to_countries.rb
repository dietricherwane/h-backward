class AddCodeToCountries < ActiveRecord::Migration
  def change
    add_column :countries, :code, :string, limit: 3
  end
end
