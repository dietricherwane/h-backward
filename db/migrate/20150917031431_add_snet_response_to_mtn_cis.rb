class AddSnetResponseToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :snet_init_response, :text
    add_column :mtn_cis, :snet_init_error_response, :text
  end
end
