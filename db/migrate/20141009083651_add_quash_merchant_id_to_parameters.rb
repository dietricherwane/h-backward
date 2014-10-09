class AddQuashMerchantIdToParameters < ActiveRecord::Migration
  def change
    add_column :parameters, :qash_merchant_id, :string
  end
end
