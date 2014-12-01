class AddFrontOfficeUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :front_office_url, :string, limit: 100
  end
end
