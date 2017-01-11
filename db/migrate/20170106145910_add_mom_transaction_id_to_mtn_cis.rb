class AddMomTransactionIdToMtnCis < ActiveRecord::Migration
  def change
     add_column :mtn_cis, :mom_transaction_id, :string
  end
end
