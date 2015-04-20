class AddPaidTransactionAmountAndPaidCurrencyIdToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :paid_transaction_amount, :float
    add_column :baskets, :paid_currency_id, :integer
  end
end
