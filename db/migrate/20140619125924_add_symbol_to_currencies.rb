class AddSymbolToCurrencies < ActiveRecord::Migration
  def change
    add_column :currencies, :symbol, :string, limit: 7
  end
end
