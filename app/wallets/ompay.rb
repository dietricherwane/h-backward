module Wallets
  class Ompay
    class << self
      def unload # process_payment
      end

      def reload # deposit
      end

      def get_token
        HTTParty.post(
          ENV['orange_money_initialization_url'],
          body: {
            merchantid: ENV['orange_money_merchant_id'],
            amount: @transaction_amount + (@basket.fees.ceil rescue @basket.first.fees.ceil),
            sessionid:@basket.transaction_id,
            purchaseref: @basket.number
          },
          headers: {
            'Content-Type' => "application/x-www-form-urlencoded"
          },
          followlocation: true
          # body: "merchantid=" + ENV['orange_money_merchant_id'] + "&amount=#{@transaction_amount + (@basket.fees.ceil rescue @basket.first.fees.ceil)}&sessionid=#{@basket.transaction_id rescue @basket.first.transaction_id}&purchaseref=#{@basket.number rescue @basket.first.number}",
        )
        @log = OmLog.create(log_rl: "OM initialization -- " + ENV['orange_money_initialization_url'] + "?" + "merchantid=" + ENV['orange_money_merchant_id'] + "&amount=#{@transaction_amount + (@basket.fees.ceil rescue @basket.first.fees.ceil)}&sessionid=#{@basket.transaction_id rescue @basket.first.transaction_id}&purchaseref=#{@basket.number rescue @basket.first.number}") rescue nil

        # request.on_complete { |response| response.success? ? response.body.strip : nil }

        # request.run
      end

      def validate_transaction(payment_token)
        HTTParty.post(
          ENV['orange_money_verify_url'],
          body: {
            merchantid: ENV['orange_money_merchant_id'],
            token: payment_token
          },
          headers: {
            'Content-Type' => "application/x-www-form-urlencoded"
          },
          # body: "merchantid=#{ENV['orange_money_merchant_id']}&token=#{@token}",
          # followlocation: true
        )

        request.on_complete do |response|
          result = nil
          result =  response.body.strip if response.success?
        end

        # request.run

        @log.update_attributes(log_tv: result.to_s)
        /status=.*;/.match(result).to_s.sub("status=", "")[0..0] == "0" ? true : false
      end
    end
  end
end
