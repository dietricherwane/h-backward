class AddQashVerifyUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :qash_verify_url, :string
  end
end
