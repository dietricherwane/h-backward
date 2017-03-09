module Wallets
  class Mtnmomo
    include HTTParty

    # base_uri ENV['mtn_sdp_uri']

    def initialize(transaction_details)
      @transaction_details = transaction_details
    end

    def unload # RequestPayment
      payload = build_request_payload(:payment, @transaction_details)
      # HTTParty.post()
      self.class.post(
        ENV['mtn_payment_request_url'],
        body: payload,
        headers: {
          "Accept" => "text/xml",
        }
      )
    end

    def reload # DepositRequest
      payload = build_request_payload(:deposit, @transaction_details)
      # HTTParty.post()
      self.class.post(
        ENV['mtn_deposit_request_url'],
        body: payload,
        headers: {
          "Accept" => "text/xml",
        }
      )
    end

    # def check_account_balance()
    # end

    def build_request_payload(transaction_type, transaction_details)
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      sdp_password = Digest::MD5.hexdigest(ENV['mtn_sdp_id'] + ENV['mtn_sdp_password'] + timestamp)

      case transaction_type
      when :payment
        payload = %Q[
          <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:b2b="http://b2b.mobilemoney.mtn.zm_v1.0">
            <soapenv:Header>
              <RequestSOAPHeader xmlns="http://www.huawei.com.cn/schema/common/v2_1">
                <spId>#{ENV['mtn_sdp_id']}</spId>
                <spPassword>#{sdp_password}</spPassword>
                <timeStamp>#{timestamp}</timeStamp>
              </RequestSOAPHeader>
            </soapenv:Header>
            <soapenv:Body>
              <b2b:processRequest>
                <serviceId>200</serviceId>
                <parameter>
                  <name>DueAmount</name>
                  <value>#{transaction_details[:due_amount]}</value>
                </parameter>
                <parameter>
                  <name>MSISDNNum</name>
                  <value>#{transaction_details[:msisdn]}</value>
                </parameter>
                <parameter>
                  <name>ProcessingNumber</name>
                  <value>#{transaction_details[:processing_number]}</value>
                </parameter>
                <parameter>
                  <name>serviceId</name>
                  <value>#{ENV['mtn_service_id']}</value>
                </parameter>
                <parameter>
                  <name>OpCoID</name>
                  <value>#{ENV['mtn_operation_country_id']}</value>
                </parameter>
              </b2b:processRequest>
            </soapenv:Body>
          </soapenv:Envelope>]
      when :deposit
        payload = %Q[<?xml version="1.0" encoding="utf-8"?>
          <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:b2b="http://b2b.mobilemoney.mtn.zm_v1.0/">
            <SOAP-ENV:Header>
              <b2b:RequestSOAPHeader xmlns="http://www.huawei.com.cn/schema/common/v2_1">
                <b2b:spId>#{ENV['mtn_sdp_id']}</b2b:spId>
                <b2b:spPassword>#{ENV['mtn_sdp_password']}</b2b:spPassword>
                <b2b:timeStamp>#{timestamp}</b2b:timeStamp>
              </b2b:RequestSOAPHeader>
            </SOAP-ENV:Header>
            <SOAP-ENV:Body>
              <b2b:processRequest>
                <serviceId>201</serviceId>
                <parameter>
                  <name>ProcessingNumber</name>
                  <value>#{transaction_details[:processing_number]}</value>
                </parameter>
                <parameter>
                  <name>serviceId</name>
                  <value>#{ENV['mtn_service_id']}</value>
                </parameter>
                <parameter>
                  <name>SenderID</name>
                  <value>#{ENV['mtn_sender_id']}</value>
                </parameter>
                <parameter>
                  <name>PrefLang</name>
                  <value>#{ENV['mtn_pref_lang']}</value>
                </parameter>
                <parameter>
                  <name>OpCoID</name>
                  <value>ic</value>
                </parameter>
                <parameter>
                  <name>MSISDNNum</name>
                  <value>#{transaction_details[:msisdn]}</value>
                </parameter>
                <parameter>
                  <name>Amount</name>
                  <value>#{transaction_details[:due_amount]}</value>
                </parameter>
                <parameter>
                  <name>OrderDateTime</name>
                  <value>#{timestamp}</value>
                </parameter>
                <parameter>
                  <name>CurrCode</name>
                  <value>#{ENV['mtn_currency_code']}</value>
                </parameter>
              </b2b:processRequest>
            </SOAP-ENV:Body>
          </SOAP-ENV:Envelope>]
      end
      payload
    end
  end
end
