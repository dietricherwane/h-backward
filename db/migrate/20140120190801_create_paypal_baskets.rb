class CreatePaypalBaskets < ActiveRecord::Migration
  def change
    create_table :paypal_baskets do |t|
      t.string :number
      t.integer :service_id
      t.integer :operation_id
      t.boolean :payment_status
      t.float :transaction_amount

      t.timestamps
    end
  end
end
