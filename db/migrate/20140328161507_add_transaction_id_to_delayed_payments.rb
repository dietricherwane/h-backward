class AddTransactionIdToDelayedPayments < ActiveRecord::Migration
  def change
    add_column :delayed_payments, :transaction_id, :string
  end
end
