class CreateEcommerceProfiles < ActiveRecord::Migration
  def change
    create_table :ecommerce_profiles do |t|
      t.string :description
      t.string :token
      t.boolean :published

      t.timestamps
    end
  end
end
