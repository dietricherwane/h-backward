class CreateOmLogs < ActiveRecord::Migration
  def change
    create_table :om_logs do |t|
      t.text :log_rl
      t.text :log_tv

      t.timestamps
    end
  end
end
