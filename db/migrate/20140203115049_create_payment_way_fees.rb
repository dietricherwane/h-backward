class CreatePaymentWayFees < ActiveRecord::Migration
  def change
    create_table :payment_way_fees do |t|
      t.string :code
      t.string :name
      t.integer :fee
      t.boolean :percentage

      t.timestamps
    end
  end
end
