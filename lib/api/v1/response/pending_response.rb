module Api::V1::Response
  class PendingResponse
    STATUS_CODE = '02'
    STATUS = 'pending'
    RESPONSE_DESC = 'En attente de la confirmaion du client.'

    def self.format_response(payment_method, basket)
      buid_response
    end

    private

    def build_response
      %Q[{"code": "#{STATUS_CODE}", "status": "#{STATUS}", "description": "#{RESPONSE_DESC}", "data": { "transaction_id": "#{basket.transaction_id}", "transaction_date": "#{basket.created_at}", "payment_method": "#{payment_method}" }}]
    end
  end
end
