class CreateLogs < ActiveRecord::Migration
  def change
    create_table :logs do |t|
      t.string :description
      t.text :sent_request
      t.text :sent_response

      t.timestamps
    end
  end
end
