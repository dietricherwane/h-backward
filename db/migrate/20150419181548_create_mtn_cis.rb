class CreateMtnCis < ActiveRecord::Migration
  def change
    create_table :mtn_cis do |t|
      t.string :number
      t.integer :service_id
      t.integer :operation_id
      t.boolean :payment_status
      t.float :transaction_amount
      t.boolean :notified_to_back_office
      t.string :transaction_id
      t.float :fees
      t.integer :currency_id
      t.float :paid_transaction_amount
      t.integer :paid_currency_id
      t.float :rate
      t.float :conflictual_transaction_amount
      t.string :conflictual_currency, limit: 3
      t.float :compensation_rate
      t.float :original_transaction_amount
      t.string :refoper

      t.timestamps
    end
  end
end
