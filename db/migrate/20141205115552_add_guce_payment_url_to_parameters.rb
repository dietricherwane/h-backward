class AddGucePaymentUrlToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :guce_payment_url, :string
  end
end
