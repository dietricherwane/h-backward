module Wallets
  class Paymoney
    include HTTParty

    # base_uri ENV['paymoney_wallet_url']

    # {
    #   service_profile_token: ,
    #   paymoney_token: ,
    #   token: ,
    #   transaction_amount: ,
    #   fees: ,
    #   transaction_id: ,
    #   password:
    # }

    def initialize(transaction_details)
      @transaction_details = transaction_details
    end

    def unload # RequestPayment
      uri = "/PAYMONEY_WALLET/rest/operation_ecommerce/#{@transaction_details[:service_profile_token]}/#{@transaction_details[:paymoney_token]}/#{@transaction_details[:token]}/#{@transaction_details[:transaction_amount]}/#{@transaction_details[:fees]}/0/#{@transaction_details[:transaction_id]}/#{@transaction_details[:password]}"
      # HTTParty.post()
      self.class.get(ENV['paymoney_wallet_url'] + uri)
    end

    def reload # DepositRequest
      uri = "/PAYMONEY-NGSER/rest/OperationService/CreditOperation/1/#{@transaction_details[:account]}/#{@transaction_details[:transaction_amount].to_i.abs}"
      # HTTParty.post()
      self.class.get(ENV['paymoney_wallet_url'] + uri)
    end

    def get_account_token
      uri = "/PAYMONEY_WALLET/rest/check2_compte/#{@transaction_details[:account_number]}"
      # HTTParty.post()
      self.class.get(ENV['paymoney_wallet_url'] + uri)
    end

    def change_status
      uri = "/GATEWAY/rest/ES/ChangeStatus/#{@pin}"
      # HTTParty.post()
      self.class.get(ENV['paymoney_wallet_url'] + uri)
    end

    def verify_pin
      uri = "/GATEWAY/rest/ES/VerifyPin/#{@pin}"
      # HTTParty.post()
      self.class.get(ENV['paymoney_wallet_url'] + uri)
    end
  end
end
