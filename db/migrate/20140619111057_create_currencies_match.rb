class CreateCurrenciesMatch < ActiveRecord::Migration
  def change
    create_table :currencies_matches, :id => false do |t|
      t.string :first_code, limit: 3
      t.string :second_code, limit: 3
      t.float :rate
    end
  end
end
