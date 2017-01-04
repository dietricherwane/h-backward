class CreateCurrencies < ActiveRecord::Migration
  def change
    create_table :currencies do |t|
      t.string :name, limit: 64
      t.string :code, limit: 3

      t.timestamps
    end
  end
end
