class AddFeeToServices < ActiveRecord::Migration
  def change
    add_column :services, :fee, :float
  end
end
