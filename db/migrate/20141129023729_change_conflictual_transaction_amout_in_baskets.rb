class ChangeConflictualTransactionAmoutInBaskets < ActiveRecord::Migration
  def change
    remove_column :baskets, :conflictual_transaction_amout
    add_column :baskets, :conflictual_transaction_amount, :float
  end
end
