class AddSucceedTransactionsAndFailedTransactionsToAvailableWallets < ActiveRecord::Migration
  def change
    add_column :available_wallets, :succeed_transactions, :integer
    add_column :available_wallets, :failed_transactions, :integer
  end
end
