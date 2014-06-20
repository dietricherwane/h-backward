class AddPublishedToCurrencies < ActiveRecord::Migration
  def change
    add_column :currencies, :published, :boolean
  end
end
