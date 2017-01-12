class AddCurrencyIdToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :currency_id, :integer
  end
end
