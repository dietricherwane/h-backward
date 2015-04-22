class AddFieldsToMtnCis < ActiveRecord::Migration
  def change
    add_column :mtn_cis, :number, :string
    add_column :mtn_cis, :service_id, :integer
    add_column :mtn_cis, :operation_id, :integer
    add_column :mtn_cis, :payment_status, :boolean
    add_column :mtn_cis, :transaction_amount, :float
    add_column :mtn_cis, :notified_to_back_office, :boolean
    add_column :mtn_cis, :transaction_id, :string
    add_column :mtn_cis, :fees, :float
    add_column :mtn_cis, :currency_id, :integer
    add_column :mtn_cis, :paid_transaction_amount, :float
    add_column :mtn_cis, :paid_currency_id, :integer
    add_column :mtn_cis, :rate, :float
    add_column :mtn_cis, :conflictual_transaction_amount, :float
    add_column :mtn_cis, :conflictual_currency, :string
    add_column :mtn_cis, :compensation_rate, :float
    add_column :mtn_cis, :original_transaction_amount, :float
    add_column :mtn_cis, :process_online_response_code, :string, limit: 5
    add_column :mtn_cis, :process_online_response_message, :text
    add_column :mtn_cis, :process_online_client_number, :string, limit: 16
    add_column :mtn_cis, :real_time_code, :string
    add_column :mtn_cis, :real_time_numfacture, :string
    add_column :mtn_cis, :real_time_datefacture, :datetime
    add_column :mtn_cis, :real_time_delaipaiement, :datetime
    add_column :mtn_cis, :real_time_montant, :float
    add_column :mtn_cis, :real_time_ch_str_xx, :string
    add_column :mtn_cis, :real_time_ch_long_xx, :integer, limit: 8
    add_column :mtn_cis, :real_time_ch_date_xx, :datetime
    add_column :mtn_cis, :real_time_ch_money_xx, :float
    add_column :mtn_cis, :real_time_transact, :string
    add_column :mtn_cis, :login_id, :string
  end
end
