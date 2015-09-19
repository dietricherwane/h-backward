class AddGuceBackOfficeUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :guce_back_office_url, :string
  end
end
