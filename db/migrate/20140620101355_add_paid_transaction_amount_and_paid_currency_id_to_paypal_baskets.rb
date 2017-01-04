class AddPaidTransactionAmountAndPaidCurrencyIdToPaypalBaskets < ActiveRecord::Migration
  def change
    add_column :paypal_baskets, :paid_transaction_amount, :float
    add_column :paypal_baskets, :paid_currency_id, :integer
  end
end
