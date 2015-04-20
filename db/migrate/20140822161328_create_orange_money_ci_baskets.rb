class CreateOrangeMoneyCiBaskets < ActiveRecord::Migration
  def change
    create_table :orange_money_ci_baskets do |t|
      t.string :number
      t.string :service_id
      t.boolean :payment_status
      t.string :operation_id
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

      t.timestamps
    end
  end
end
