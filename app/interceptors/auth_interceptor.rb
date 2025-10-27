# frozen_string_literal: true

require 'active_support/isolated_execution'
require 'concerns/current'

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(GRPC::Core::StatusCodes::UNAUTHENTICATED, "Unauthenticated: user-id metadata is missing")

  def request_response(request:, call:, method:)
    user_id = call.metadata['user-id']

    if user_id.nil? || user_id.empty?
      raise UNAUTHENTICATED
    end

    ActiveSupport::IsolatedExecution.with_isolation do
      Current.user_id = user_id
      yield
    end
  end
end
