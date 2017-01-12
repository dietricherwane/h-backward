class CreateFees < ActiveRecord::Migration
  def change
    create_table :fees do |t|
      t.integer :fee_type_id
      t.float :min_value
      t.float :max_value
      t.float :fee_value

      t.timestamps
    end
    add_index :fees, :fee_type_id
  end
end
