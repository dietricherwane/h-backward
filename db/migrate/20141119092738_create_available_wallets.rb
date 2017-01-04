class CreateAvailableWallets < ActiveRecord::Migration
  def change
    create_table :available_wallets do |t|
      t.integer :service_id
      t.integer :wallet_id
      t.boolean :published
      t.integer :unpublished_by
      t.datetime :unpublished_at
      t.integer :published_by
      t.datetime :published_at

      t.timestamps
    end
  end
end
