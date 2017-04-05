module Api::V1::Auth
  def authenticate
    raise "L'authentification a échoué." unless verify_token
  rescue Exception => e
    render json: Api::V1::Response::ErrorResponse::format_response('10', e.message), status: :unauthorized
  end

  def verify_token
    return false if request.headers[:authorization].blank?
    auth_parts = request.headers[:authorization].split(" ")
    req_operation, req_token = auth_parts[1].split(":")
    auth_parts[0] == "NGSER" && req_token == rebuild_auth_token
  end

  def rebuild_auth_token
    service_token = Operation.where(authentication_token: params[:operation_token]).first.service.authentication_token
    data = string_to_sign.force_encoding('iso-8859-5').encode('utf-8')
    OpenSSL::HMAC.hexdigest('SHA256', service_token, data)
  end

  def string_to_sign
    request_content_type = params[:content_type].nil? ? request.content_type : params[:content_type]
    path = params[:path].nil? ? request.original_fullpath : params[:path]
    resource_path = '/api/paymoney' + path + '.' + request.params[:format].to_s

    %Q[#{request.request_method.upcase}

#{request_content_type}
#{params[:transaction_date]}
#{resource_path}]
  end
end
