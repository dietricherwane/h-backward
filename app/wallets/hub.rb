module Wallets
  class Hub
    include HTTParty

    # {
    #   operation_token: ,
    #   mobile_money_token: ,
    #   paymoney_account_number: ,
    #   paymoney_password: ,
    #   transaction_id: ,
    #   original_transaction_amount: ,
    #   fees:
    # }

    def initialize(transaction_details)
      @transaction_details = transaction_details
    end

    def unload
      uri = "/api/88bc43ed59e5207c68e864564/mobile_money/cashout/Mtn/#{@operation_token}/#{@mobile_money_token}/#{@basket.paymoney_account_number}/#{@paymoney_password}/#{@basket.transaction_id}/#{@basket.original_transaction_amount}/#{(@basket.fees / @basket.rate).ceil.round(2)}"
      # HTTParty.post()
      self.class.get(ENV['gateway_wallet_url'] + uri)
    end

    def reload
      uri = "/api/86d138798bc43ed59e5207c664/mobile_money/cashin/Mtn/#{@operation_token}/#{@mobile_money_token}/#{@basket.paymoney_account_number}/#{@basket.transaction_id}/#{@basket.original_transaction_amount}/0"
      # HTTParty.post()
      self.class.get(ENV['gateway_wallet_url'] + uri)
    end
  end
end
