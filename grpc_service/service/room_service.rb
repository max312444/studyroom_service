# grpc_service/service/room_service.rb
# frozen_string_literal: true
require 'room/room_pb'
require 'room/service_pb'
require 'room/service_services_pb'

module Bannote
  module Studyroomservice
    module Room
      module V1
        class RoomServiceHandler < Bannote::Studyroomservice::Room::V1::RoomService::Service
          def create_room(request, _call)
            # 데이터베이스에서 Room 객체 생성
            new_room = ::Room.create!(
              name: request.name,
              maximum_member: request.minimum_member,
              department_code: request.department_id.to_s,
              department_name: "Unknown", # 임시값, 외부 서비스 연동 필요
              created_by: 1 # 임시값, 인증 시스템 연동 필요
            )

            # gRPC 응답 메시지 생성
            Bannote::Studyroomservice::Room::V1::CreateRoomResponse.new(
              room: room_to_proto(new_room)
            )
          rescue ActiveRecord::RecordInvalid => e
            # 유효성 검사 실패 시 에러 처리
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: e.message)
          end

          def get_room(request, _call)
            room = ::Room.find(request.id)

            Bannote::Studyroomservice::Room::V1::GetRoomResponse.new(
              room: room_to_proto(room)
            )
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room not found")
          end

          def list_rooms(_request, _call)
            rooms = ::Room.all
            Bannote::Studyroomservice::Room::V1::ListRoomsResponse.new(
              rooms: rooms.map { |room| room_to_proto(room) }
            )
          end

          def update_room(request, _call)
            room = ::Room.find(request.id)
            room.update!(
              name: request.name,
              maximum_member: request.minimum_member,
              department_code: request.department_id.to_s
            )

            Bannote::Studyroomservice::Room::V1::UpdateRoomResponse.new(
              room: room_to_proto(room)
            )
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room not found")
          rescue ActiveRecord::RecordInvalid => e
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: e.message)
          end

          def delete_room(request, _call)
            room = ::Room.find(request.id)
            room.destroy!

            Bannote::Studyroomservice::Room::V1::DeleteRoomResponse.new
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room not found")
          end

          private

          def room_to_proto(room)
            Bannote::Studyroomservice::Room::V1::Room.new(
              id: room.id,
              name: room.name,
              minimum_member: room.maximum_member,
              department_name: room.department_name,
              created_at: Google::Protobuf::Timestamp.new(seconds: room.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: room.updated_at.to_i),
              created_by: room.created_by
            )
          end
        end
      end
    end
  end
end