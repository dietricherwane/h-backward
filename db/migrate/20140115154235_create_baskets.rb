class CreateBaskets < ActiveRecord::Migration
  def change
    create_table :baskets do |t|
      t.integer :number
      t.integer :service_id

      t.timestamps
    end
  end
end
