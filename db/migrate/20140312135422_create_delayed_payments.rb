class CreateDelayedPayments < ActiveRecord::Migration
  def change
    create_table :delayed_payments do |t|
      t.string :number
      t.integer :service_id
      t.boolean :payment_status
      t.integer :operation_id
      t.boolean :notified_to_back_office
      t.float :transaction_amount

      t.timestamps
    end
  end
end
