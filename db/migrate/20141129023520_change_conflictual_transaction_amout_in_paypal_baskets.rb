class ChangeConflictualTransactionAmoutInPaypalBaskets < ActiveRecord::Migration
  def change
    remove_column :paypal_baskets, :conflictual_transaction_amout
    add_column :paypal_baskets, :conflictual_transaction_amount, :float
  end
end
