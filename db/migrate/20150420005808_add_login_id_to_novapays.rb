class AddLoginIdToNovapays < ActiveRecord::Migration
  def change
    add_column :novapays, :login_id, :string
  end
end
