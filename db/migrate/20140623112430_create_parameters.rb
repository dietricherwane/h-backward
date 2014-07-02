class CreateParameters < ActiveRecord::Migration
  def change
    create_table :parameters do |t|
      t.string :second_origin_url

      t.timestamps
    end
  end
end
