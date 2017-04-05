module Api::V1::Response
  class SuccessResponse
    STATUS_CODE = '01'
    STATUS = 'success'
    RESPONSE_DESC = 'La transaction a bien été effectué.'

    def self.format_response(payment_method, basket, info)
      buid_response(info)
    end

    private

    def build_response(info = nil)
      %Q[{"code": "#{STATUS_CODE}", "status": "#{STATUS}", "description": "#{info || RESPONSE_DESC}", "data": { "transaction_id": "#{basket.transaction_id}", "transaction_date": "#{basket.created_at}", "payment_method": "#{payment_method}" }}]
    end
  end
end
