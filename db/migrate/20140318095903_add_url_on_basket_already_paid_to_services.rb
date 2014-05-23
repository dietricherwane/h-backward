class AddUrlOnBasketAlreadyPaidToServices < ActiveRecord::Migration
  def change
    add_column :services, :url_on_basket_already_paid, :string
  end
end
