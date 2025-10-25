#!/usr/bin/env ruby
# frozen_string_literal: true

require 'grpc'

# =====================================================
# 1. Ruby가 gRPC 파일들을 찾을 수 있도록 경로 추가
# =====================================================
$LOAD_PATH.unshift(File.expand_path('../app/grpc', __dir__))
$LOAD_PATH.unshift(File.expand_path('../app', __dir__))

# =====================================================
# 2. Rails 환경 로드
# =====================================================
require_relative '../config/environment'

# =====================================================
# 3. Proto 파일 로드
# =====================================================
require 'room/room_pb'
require 'room/service_pb'
require 'room/service_services_pb'

require 'reservation/reservation_pb'
require 'reservation/service_pb'
require 'reservation/service_services_pb'

# =====================================================
# 4. 서비스 핸들러 로드
# =====================================================
require_relative './service/room_service'
require_relative './service/reservation_service'

# =====================================================
# 5. gRPC 서버 실행
# =====================================================
module Bannote
  module Studyroomservice
    module V1
      def self.start
        server = GRPC::RpcServer.new
        port = '0.0.0.0:50052'
        server.add_http2_port(port, :this_port_is_insecure)

        # 서비스 등록
        server.handle(Bannote::Studyroomservice::Room::V1::RoomServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Reservation::V1::ReservationServiceHandler.new)

        puts "gRPC server listening on #{port}"
        server.run_till_terminated
      end
    end
  end
end

Bannote::Studyroomservice::V1.start
