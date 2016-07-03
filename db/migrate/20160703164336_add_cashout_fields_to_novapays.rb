class AddCashoutFieldsToNovapays < ActiveRecord::Migration
  def change
    add_column :novapays, :cashout, :boolean
    add_column :novapays, :cashout_completed, :boolean
    add_column :novapays, :paymoney_password, :string
  end
end
