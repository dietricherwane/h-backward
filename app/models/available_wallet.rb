class AvailableWallet < ActiveRecord::Base
  # Accessible fields
  attr_accessible :service_id, :wallet_id, :published, :unpublished_by, :unpublished_at, :published_by, :published_at, :wallet_used, :succeed_transactions, :failed_transactions

  # Relationships
  belongs_to :service
  belongs_to :wallet
end
