# app/interceptors/auth_interceptor.rb
# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: user-id metadata is missing"
  )

  def request_response(request:, call:, method:)
    user_id = call.metadata['user-id']

    if user_id.nil? || user_id.empty?
      raise UNAUTHENTICATED
    end

    # Rails 환경에서는 ActiveSupport::IsolatedExecution 불필요
    Current.user_id = user_id
    yield
  ensure
    # 요청이 끝나면 Current 컨텍스트를 정리
    Current.user_id = nil
  end
end
