class AddAttachmentLogoToWallets < ActiveRecord::Migration
  def self.up
    change_table :wallets do |t|
      t.attachment :logo
    end
  end

  def self.down
    remove_attachment :wallets, :logo
  end
end
