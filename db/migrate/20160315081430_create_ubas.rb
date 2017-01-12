class CreateUbas < ActiveRecord::Migration
  def change
    create_table :ubas do |t|
      t.string :firstname
      t.string :lastname
      t.string :email
      t.string :phone_number
      t.string :order_id
      t.string :username
      t.string :password
      t.string :channel_id
      t.integer :service_id
      t.boolean :payment_status
      t.integer :operation_id
      t.float :transaction_amount
      t.boolean :notified_to_back_office
      t.string :transaction_id
      t.float :fees
      t.integer :currency_id
      t.float :paid_transaction_amount
      t.integer :paid_currency_id
      t.float :rate
      t.float :conflictual_transaction_amount
      t.string :conflictual_currency
      t.float :compensation_rate
      t.float :original_transaction_amount
      t.string :login_id
      t.string :txn_id
      t.text :uba_redirect_url
      t.text :uba_redirect_response
      t.text :return_params

      t.timestamps
    end
  end
end
