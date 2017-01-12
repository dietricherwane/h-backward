class AddPublishedToOperations < ActiveRecord::Migration
  def change
    add_column :operations, :published, :boolean
  end
end
