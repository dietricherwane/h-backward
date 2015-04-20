class AddUrlToIpnToService < ActiveRecord::Migration
  def change
    add_column :services, :url_to_ipn, :string
  end
end
