class AddAcknowledgementCountToBaskets < ActiveRecord::Migration
  def change
    add_column :baskets, :acknowledgement_count, :integer
  end
end
