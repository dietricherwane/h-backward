class AddLoginIdToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :login_id, :string
  end
end
