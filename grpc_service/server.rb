# frozen_string_literal: true

require 'grpc'

# gRPC 폴더를 Ruby의 LOAD_PATH에 추가
$LOAD_PATH.unshift(File.expand_path('../app/grpc', __dir__))

# =====================================================
# Room 관련 proto 로드 (app/grpc/room)
# =====================================================
require_relative '../app/grpc/room/room_pb'
require_relative '../app/grpc/room/service_pb'
require_relative '../app/grpc/room/service_services_pb'


# =====================================================
# Reservation 관련 proto 로드 (app/grpc/reservation)
# =====================================================
require_relative '../app/grpc/reservation/reservation_pb'
require_relative '../app/grpc/reservation/service_pb'
require_relative '../app/grpc/reservation/service_services_pb'

# =====================================================
# RoomException 관련 proto 로드
# =====================================================
require_relative '../app/grpc/room_exception/room_exception_pb'
require_relative '../app/grpc/room_exception/service_pb'
require_relative '../app/grpc/room_exception/service_services_pb'

# =====================================================
# RoomOperatingHour 관련 proto 로드
# =====================================================
require_relative '../app/grpc/room_operating_hour/room_operating_hour_pb'
require_relative '../app/grpc/room_operating_hour/service_pb'
require_relative '../app/grpc/room_operating_hour/service_services_pb'


# =====================================================
# RoomService Handler
# =====================================================
module Studyroom
  module Room
    module V1
      class RoomServiceHandler < RoomService::Service
        # 룸 생성
        def create_room(request, _call)
          # 유효성 검사
          if request.name.nil? || request.name.strip.empty?
            raise GRPC::InvalidArgument, "Room name is required."
          end

          # DB 저장
          room = ::Room.create!(
            name: request.name,
            capacity: request.capacity,
            location: request.location # 이건 DB에 없던거 같은데 일단 함
          )

          # gRPC 응답 메시지
          Studyroom::Room::V1::CreateRoomResponse.new(
            room: Studyroom::Room::V1::Room.new(
              id: room.id,
              name: room.name,
              capacity: room.capacity,
              location: room.location
            )
          )

        rescue ActiveRecord::RecordInvalid => e
          # 유효성 검사 실패 시
          raise GRPC::InvalidArgument, e.message
        raise => e
          # 기타 에러
          raise GRPC::Internal, "Failed to create room: #{e.message}"
        end

        # 룸 단일 조회
        def get_room(request, _call)

        end

        # 룸 목록 조회
        def list_rooms(_request, _call)

        end

        # 룸 삭제
        def delete_room(request, _call)

        end
      end
    end
  end
end


# =====================================================
# ReservationService Handler
# =====================================================
module Studyroom
  module Reservation
    module V1
      class ReservationServiceHandler < ReservationService::Service
        # 예약 생성
        def create_reservation(request, _call)
          reservation = Reservation.new(
            id: 1,
            code: "ABC123",
            room_id: request.room_id,
            group_id: request.group_id,
            link_id: request.link_id,
            start_time: request.start_time,
            end_time: request.end_time,
            purpose: request.purpose,
            priority: request.priority
          )
          CreateReservationResponse.new(reservation: reservation)
        end

        # 예약 단일 조회
        def get_reservation(request, _call)
          reservation = Reservation.new(
            id: 1,
            code: (request.code.nil? || request.code.empty?) ? "ABC123" : request.code,
            room_id: 2,
            group_id: 0,
            link_id: 0,
            purpose: "조회 테스트용 예약",
            priority: :RESERVATION_PRIORITY_MEDIUM
          )
          GetReservationResponse.new(reservation: reservation)
        end

        # 사용자별 예약 목록 조회
        def list_reservations_by_user(request, _call)
          reservations = [
            Reservation.new(
              id: 1,
              code: "U001",
              room_id: 1,
              purpose: "사용자 #{request.user_id}의 예약 1"
            ),
            Reservation.new(
              id: 2,
              code: "U002",
              room_id: 2,
              purpose: "사용자 #{request.user_id}의 예약 2"
            )
          ]
          ListReservationsByUserResponse.new(reservations: reservations)
        end

        # 룸별 예약 목록 조회
        def list_reservations_by_room(request, _call)
          reservations = [
            Reservation.new(
              id: 1,
              code: "R001",
              room_id: request.room_id,
              purpose: "룸 #{request.room_id}의 오전 예약"
            ),
            Reservation.new(
              id: 2,
              code: "R002",
              room_id: request.room_id,
              purpose: "룸 #{request.room_id}의 오후 예약"
            )
          ]
          ListReservationsByRoomResponse.new(reservations: reservations)
        end

        # 예약 취소
        def cancel_reservation(request, _call)
          puts "Canceled reservation code: #{request.code}"
          CancelReservationResponse.new(success: true, message: "Reservation #{request.code} canceled.")
        end
      end
    end
  end
end


# =====================================================
# gRPC 서버 실행부
# =====================================================
def main
  port = '0.0.0.0:50051'
  server = GRPC::RpcServer.new
  server.add_http2_port(port, :this_port_is_insecure)

  # 서비스 등록
  server.handle(Studyroom::Room::V1::RoomServiceHandler)
  server.handle(Studyroom::Reservation::V1::ReservationServiceHandler)

  puts "✅ gRPC server listening on port 50051..."
  server.run_till_terminated
end

main
