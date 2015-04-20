class AddLoginIdToQashBaskets < ActiveRecord::Migration
  def change
    add_column :qash_baskets, :login_id, :string
  end
end
