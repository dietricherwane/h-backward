class RemoveOrginalTransactionAmountFromNovapays < ActiveRecord::Migration
  def change
    remove_column :novapays, :orginal_transaction_amount
  end
end
