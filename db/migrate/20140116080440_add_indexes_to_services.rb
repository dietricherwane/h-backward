class AddIndexesToServices < ActiveRecord::Migration
  def change
    add_index :services, :code
    add_index :services, :name
  end
end
