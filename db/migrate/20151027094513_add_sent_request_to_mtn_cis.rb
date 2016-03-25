class AddSentRequestToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :sent_request, :text
  end
end
