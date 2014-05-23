class CreateOperations < ActiveRecord::Migration
  def change
    create_table :operations do |t|
      t.string :code
      t.string :name
      t.string :comment
      t.integer :service_id

      t.timestamps
    end
  end
end
