module Api::V1::Response
  class FailResponse
    STATUS = 'fail'

    def self.format_response(code, errors)
      build_response(code, errors)
    end

    private

    def self.build_response(code, errors)
      %Q[{"code": "#{code.to_s}", "status": "#{STATUS.to_s}", "errors_messages": #{errors}}]
    end
  end
end
