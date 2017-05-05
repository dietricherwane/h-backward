class Parameter < ActiveRecord::Base
  attr_accessible :second_origin_url, :paymoney_url, :orange_money_ci_initialization_url, :orange_money_ci_url, :qash_merchant_id, :qash_url, :qash_verify_url, :orange_money_ci_verify_url, :front_office_url, :back_office_url, :guce_back_office_url, :guce_payment_url, :paymoney_wallet_url, :gateway_wallet_url, :bni_billing_request, :bni_billing_username, :bni_billing_password, :bni_operator_id, :bni_channel_id
end
