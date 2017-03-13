module Wallets
  class Paymoney

    BASE_URI = ENV['paymoney_wallet_url']

    # {
    #   service_profile_token: ,
    #   paymoney_token: ,
    #   token: ,
    #   transaction_amount: ,
    #   fees: ,
    #   transaction_id: ,
    #   password:
    # }

    class << self
      def unload(transaction_details = {}) # RequestPayment
        uri = "/PAYMONEY_WALLET/rest/operation_ecommerce/#{transaction_details[:service_profile_token]}/#{transaction_details[:paymoney_token]}/#{transaction_details[:token]}/#{transaction_details[:transaction_amount]}/#{transaction_details[:fees]}/0/#{transaction_details[:transaction_id]}/#{transaction_details[:password]}"
        HTTParty.get(BASE_URI + uri)
      end

      def reload(transaction_details = {}) # DepositRequest
        uri = "/PAYMONEY-NGSER/rest/OperationService/CreditOperation/1/#{transaction_details[:account]}/#{transaction_details[:transaction_amount].to_i.abs}"
        HTTParty.get(BASE_URI + uri)
      end

      def get_account_token(transaction_details = {})
        uri = "/PAYMONEY_WALLET/rest/check2_compte/#{transaction_details[:account_number]}"
        HTTParty.get(BASE_URI + uri)
      end

      def change_status(transaction_details = {})
        uri = "/GATEWAY/rest/ES/ChangeStatus/#{@pin}"
        HTTParty.get(BASE_URI + uri)
      end

      def verify_pin(transaction_details = {})
        uri = "/GATEWAY/rest/ES/VerifyPin/#{@pin}"
        HTTParty.get(BASE_URI + uri)
      end
    end
  end
end
