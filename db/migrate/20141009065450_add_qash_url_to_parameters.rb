class AddQashUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :qash_url, :string
  end
end
