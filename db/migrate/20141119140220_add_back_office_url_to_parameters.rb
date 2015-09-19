class AddBackOfficeUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :back_office_url, :string, limit: 100
  end
end
