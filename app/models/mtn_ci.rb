class MtnCi < ActiveRecord::Base
  belongs_to :service
  belongs_to :operation
  belongs_to :currency

  attr_accessible :number, :notified_to_ecommerce, :sent_request, :service_id, :payment_status, :operation_id, :transaction_amount, :notified_to_back_office, :transaction_id, :fees, :currency_id, :paid_transaction_amount, :paid_currency_id, :rate, :conflictual_transaction_amount, :conflictual_currency, :compensation_rate, :created_at, :original_transaction_amount, :process_online_response_code, :process_online_response_message, :process_online_client_number, :real_time_code, :real_time_numfacture, :real_time_datefacture, :real_time_delaipaiement, :real_time_montant, :real_time_ch_str_xx, :real_time_ch_long_xx, :real_time_ch_date_xx, :real_time_ch_money_xx, :real_time_transact, :login_id, :created_at, :updated_at, :snet_init_response, :snet_init_error_response, :snet_payment_response, :snet_payment_error_response, :paymoney_account_number, :paymoney_account_token, :paymoney_reload_request, :paymoney_reload_response, :paymoney_token_request, :paymoney_transaction_id, :cashout, :cashout_completed, :paymoney_password, :cashout_account_number, :cashout_notified_to_front_office, :cashout_notification_request, :cashout_notification_response, :phone_number, :type_token, :mom_transaction_id
end
