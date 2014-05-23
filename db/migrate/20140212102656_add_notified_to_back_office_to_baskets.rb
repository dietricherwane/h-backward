class AddNotifiedToBackOfficeToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :notified_to_back_office, :boolean
  end
end
