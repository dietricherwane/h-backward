# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160703090716) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "available_wallets", force: true do |t|
    t.integer  "service_id"
    t.integer  "wallet_id"
    t.boolean  "published"
    t.integer  "unpublished_by"
    t.datetime "unpublished_at"
    t.integer  "published_by"
    t.datetime "published_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "wallet_used"
    t.integer  "succeed_transactions"
    t.integer  "failed_transactions"
  end

  create_table "baskets", force: true do |t|
    t.string   "number"
    t.string   "service_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "payment_status"
    t.string   "operation_id"
    t.float    "transaction_amount"
    t.boolean  "notified_to_back_office"
    t.string   "transaction_id"
    t.boolean  "notified_to_ecommerce"
    t.float    "fees"
    t.integer  "currency_id"
    t.float    "paid_transaction_amount"
    t.integer  "paid_currency_id"
    t.float    "rate"
    t.string   "conflictual_currency",           limit: 3
    t.float    "compensation_rate"
    t.integer  "acknowledgement_count"
    t.string   "original_transaction_amount"
    t.float    "conflictual_transaction_amount"
    t.string   "login_id"
    t.text     "paymoney_account_number"
    t.string   "paymoney_account_token"
    t.text     "paymoney_reload_request"
    t.text     "paymoney_reload_response"
    t.text     "paymoney_token_request"
    t.string   "paymoney_transaction_id"
  end

  add_index "baskets", ["number"], name: "index_baskets_on_number", using: :btree
  add_index "baskets", ["operation_id"], name: "index_baskets_on_operation_id", using: :btree
  add_index "baskets", ["service_id"], name: "index_baskets_on_service_id", using: :btree

  create_table "countries", force: true do |t|
    t.boolean  "published"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "code",       limit: 3
    t.string   "name",       limit: 45
  end

  create_table "currencies", force: true do |t|
    t.string   "name",       limit: 64
    t.string   "code",       limit: 3
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "published"
    t.string   "symbol",     limit: 7
  end

  create_table "currencies_matches", id: false, force: true do |t|
    t.string "first_code",  limit: 3
    t.string "second_code", limit: 3
    t.float  "rate"
  end

  create_table "delayed_payments", force: true do |t|
    t.string   "number"
    t.string   "service_id"
    t.boolean  "payment_status"
    t.string   "operation_id"
    t.boolean  "notified_to_back_office"
    t.float    "transaction_amount"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "transaction_id"
    t.boolean  "notified_to_ecommerce"
  end

  create_table "ecommerce_profiles", force: true do |t|
    t.string   "description"
    t.string   "token"
    t.boolean  "published"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "logs", force: true do |t|
    t.string   "description"
    t.text     "sent_request"
    t.text     "sent_response"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "paymoney_account_number"
    t.text     "paymoney_token_request"
    t.text     "paymoney_token_response"
  end

  create_table "mtn_cis", force: true do |t|
    t.string   "number"
    t.integer  "service_id"
    t.integer  "operation_id"
    t.boolean  "payment_status"
    t.float    "transaction_amount"
    t.boolean  "notified_to_back_office"
    t.string   "transaction_id"
    t.float    "fees"
    t.integer  "currency_id"
    t.float    "paid_transaction_amount"
    t.integer  "paid_currency_id"
    t.float    "rate"
    t.float    "conflictual_transaction_amount"
    t.string   "conflictual_currency"
    t.float    "compensation_rate"
    t.float    "original_transaction_amount"
    t.string   "process_online_response_code",    limit: 5
    t.text     "process_online_response_message"
    t.string   "process_online_client_number",    limit: 16
    t.string   "real_time_code"
    t.string   "real_time_numfacture"
    t.datetime "real_time_datefacture"
    t.datetime "real_time_delaipaiement"
    t.float    "real_time_montant"
    t.string   "real_time_ch_str_xx"
    t.integer  "real_time_ch_long_xx",            limit: 8
    t.datetime "real_time_ch_date_xx"
    t.float    "real_time_ch_money_xx"
    t.string   "real_time_transact"
    t.string   "login_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "snet_init_response"
    t.text     "snet_init_error_response"
    t.text     "snet_payment_response"
    t.text     "snet_payment_error_response"
    t.text     "sent_request"
    t.string   "notified_to_ecommerce"
    t.text     "paymoney_account_number"
    t.string   "paymoney_account_token"
    t.text     "paymoney_reload_request"
    t.text     "paymoney_reload_response"
    t.text     "paymoney_token_request"
    t.string   "paymoney_transaction_id"
  end

  create_table "novapays", force: true do |t|
    t.string   "number"
    t.integer  "service_id"
    t.integer  "operation_id"
    t.boolean  "payment_status"
    t.float    "transaction_amount"
    t.boolean  "notified_to_back_office"
    t.string   "transaction_id"
    t.float    "fees"
    t.integer  "currency_id"
    t.float    "paid_transaction_amount"
    t.integer  "paid_currency_id"
    t.float    "rate"
    t.float    "conflictual_transaction_amount"
    t.string   "conflictual_currency",           limit: 3
    t.float    "compensation_rate"
    t.string   "refoper"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "original_transaction_amount"
    t.string   "login_id"
    t.text     "paymoney_account_number"
    t.string   "paymoney_account_token"
    t.text     "paymoney_reload_request"
    t.text     "paymoney_reload_response"
    t.text     "paymoney_token_request"
    t.string   "paymoney_transaction_id"
  end

  create_table "om_logs", force: true do |t|
    t.text     "log_rl"
    t.text     "log_tv"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "operations", force: true do |t|
    t.string   "code"
    t.string   "name"
    t.string   "comment"
    t.integer  "service_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "published"
    t.string   "authentication_token"
    t.string   "paymoney_token"
  end

  create_table "orange_money_ci_baskets", force: true do |t|
    t.string   "number"
    t.string   "service_id"
    t.boolean  "payment_status"
    t.string   "operation_id"
    t.float    "transaction_amount"
    t.boolean  "notified_to_back_office"
    t.string   "transaction_id"
    t.float    "fees"
    t.integer  "currency_id"
    t.float    "paid_transaction_amount"
    t.integer  "paid_currency_id"
    t.float    "rate"
    t.float    "conflictual_transaction_amount"
    t.string   "conflictual_currency",           limit: 3
    t.float    "compensation_rate"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ompay_token"
    t.string   "ompay_clientid"
    t.string   "ompay_cname"
    t.string   "ompay_payid"
    t.string   "ompay_date"
    t.string   "ompay_time"
    t.string   "ompay_ipaddr"
    t.string   "ompay_signature"
    t.string   "original_transaction_amount"
    t.text     "log_rl"
    t.text     "log_tv"
    t.string   "login_id"
    t.text     "paymoney_account_number"
    t.string   "paymoney_account_token"
    t.text     "paymoney_reload_request"
    t.text     "paymoney_reload_response"
    t.text     "paymoney_token_request"
    t.string   "paymoney_transaction_id"
  end

  create_table "parameters", force: true do |t|
    t.string   "second_origin_url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "paymoney_url"
    t.string   "orange_money_ci_initialization_url"
    t.string   "orange_money_ci_url"
    t.string   "qash_url"
    t.string   "qash_merchant_id"
    t.string   "qash_verify_url"
    t.string   "orange_money_ci_verify_url"
    t.string   "front_office_url",                   limit: 100
    t.string   "back_office_url",                    limit: 100
    t.string   "guce_back_office_url"
    t.string   "guce_payment_url"
    t.string   "paymoney_wallet_url"
    t.string   "gateway_wallet_url"
  end

  create_table "payment_way_fees", force: true do |t|
    t.string   "code"
    t.string   "name"
    t.float    "fee"
    t.boolean  "percentage"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "published"
    t.boolean  "enabled"
    t.integer  "wallet_id"
  end

  create_table "paypal_baskets", force: true do |t|
    t.string   "number"
    t.string   "service_id"
    t.string   "operation_id"
    t.boolean  "payment_status"
    t.float    "transaction_amount"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "notified_to_back_office"
    t.string   "transaction_id"
    t.boolean  "notified_to_ecommerce"
    t.float    "fees"
    t.integer  "currency_id"
    t.float    "paid_transaction_amount"
    t.integer  "paid_currency_id"
    t.float    "rate"
    t.string   "conflictual_currency",           limit: 3
    t.float    "compensation_rate"
    t.string   "original_transaction_amount"
    t.float    "conflictual_transaction_amount"
    t.string   "login_id"
    t.text     "paymoney_account_number"
    t.string   "paymoney_account_token"
    t.text     "paymoney_reload_request"
    t.text     "paymoney_reload_response"
    t.text     "paymoney_token_request"
    t.string   "paymoney_transaction_id"
    t.boolean  "cashout"
    t.boolean  "cashout_completed"
    t.string   "paymoney_password"
  end

  create_table "products", force: true do |t|
    t.string   "name",          limit: 100
    t.integer  "price"
    t.date     "expiring_date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "published"
  end

  create_table "qash_baskets", force: true do |t|
    t.string   "number"
    t.string   "service_id"
    t.boolean  "payment_status"
    t.string   "operation_id"
    t.float    "transaction_amount"
    t.boolean  "notified_to_back_office"
    t.string   "transaction_id"
    t.float    "fees"
    t.integer  "currency_id"
    t.float    "paid_transaction_amount"
    t.integer  "paid_currency_id"
    t.float    "rate"
    t.float    "conflictual_transaction_amount"
    t.string   "conflictual_currency",           limit: 3
    t.float    "compensation_rate"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "qash_transaction_id"
    t.string   "original_transaction_amount"
    t.string   "login_id"
    t.text     "paymoney_account_number"
    t.string   "paymoney_account_token"
    t.text     "paymoney_reload_request"
    t.text     "paymoney_reload_response"
    t.text     "paymoney_token_request"
    t.string   "paymoney_transaction_id"
  end

  create_table "services", force: true do |t|
    t.string   "code"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "sales_area"
    t.string   "url_on_success"
    t.string   "url_on_error"
    t.string   "url_on_session_expired"
    t.string   "url_on_hold_success"
    t.string   "url_on_hold_error"
    t.string   "url_on_hold_listener"
    t.string   "authentication_token"
    t.string   "comment"
    t.string   "url_on_basket_already_paid"
    t.string   "url_to_ipn"
    t.boolean  "published"
    t.string   "logo_file_name"
    t.string   "logo_content_type"
    t.integer  "logo_file_size"
    t.datetime "logo_updated_at"
    t.string   "token",                      limit: 100
    t.integer  "ecommerce_profile_id"
  end

  add_index "services", ["code"], name: "index_services_on_code", using: :btree
  add_index "services", ["name"], name: "index_services_on_name", using: :btree

  create_table "sessions", force: true do |t|
    t.string   "session_id", null: false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", unique: true, using: :btree
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at", using: :btree

  create_table "simple_captcha_data", force: true do |t|
    t.string   "key",        limit: 40
    t.string   "value",      limit: 6
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "simple_captcha_data", ["key"], name: "idx_key", using: :btree

  create_table "ubas", force: true do |t|
    t.string   "firstname"
    t.string   "lastname"
    t.string   "email"
    t.string   "phone_number"
    t.string   "username"
    t.string   "password"
    t.string   "channel_id"
    t.integer  "service_id"
    t.boolean  "payment_status"
    t.integer  "operation_id"
    t.float    "transaction_amount"
    t.boolean  "notified_to_back_office"
    t.string   "transaction_id"
    t.float    "fees"
    t.integer  "currency_id"
    t.float    "paid_transaction_amount"
    t.integer  "paid_currency_id"
    t.float    "rate"
    t.float    "conflictual_transaction_amount"
    t.string   "conflictual_currency"
    t.float    "compensation_rate"
    t.float    "original_transaction_amount"
    t.string   "login_id"
    t.string   "txn_id"
    t.text     "uba_redirect_url"
    t.text     "uba_redirect_response"
    t.text     "return_params"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "number"
    t.text     "paymoney_account_number"
    t.string   "paymoney_account_token"
    t.text     "paymoney_reload_request"
    t.text     "paymoney_reload_response"
    t.text     "paymoney_token_request"
    t.string   "paymoney_transaction_id"
  end

  create_table "wallets", force: true do |t|
    t.string   "name"
    t.string   "url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "country_id"
    t.boolean  "published"
    t.string   "authentication_token"
    t.integer  "currency_id"
    t.float    "fee"
    t.boolean  "percentage"
    t.string   "logo_file_name"
    t.string   "logo_content_type"
    t.integer  "logo_file_size"
    t.datetime "logo_updated_at"
    t.string   "table_name",           limit: 100
    t.string   "collector_id"
  end

end
