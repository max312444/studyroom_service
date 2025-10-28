# frozen_string_literal: true

require 'room/room_pb'
require 'room/service_pb'
require 'room/service_services_pb'

require_relative '../../app/models/concerns/current'
require_relative '../../app/models/concerns/simulated_user_roles'

module Bannote
  module Studyroomservice
    module Room
      module V1
        class RoomServiceHandler < Bannote::Studyroomservice::Room::V1::RoomService::Service

          # =========================================
          # 1. 방 생성
          # =========================================
          def create_room(request, _call)
            unless SimulatedUserRoles.has_authority?(
              Current.user_id,
              SimulatedUserRoles::AUTHORITY_LEVELS["assistant"]
            )
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Requires Assistant authority or higher to create a room."
              )
            end

            begin
              puts "[INFO] CreateRoom request: #{request.inspect}"

              room = ::Room.create!(
                department_code: request.department_code.to_s,
                name: request.name,
                maximum_member: request.maximum_member,
                status: request.status,
                created_by: Current.user_id
              )

              # ✅ proto 구조에 맞게 수정 — CreateRoomResponse는 room 필드만 가짐
              Bannote::Studyroomservice::Room::V1::CreateRoomResponse.new(
                room: room_to_proto(room)
              )

            rescue => e
              puts "[ERROR] #{e.class}: #{e.message}"
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::INTERNAL,
                "Failed to create room: #{e.message}"
              )
            end
          end

          # =========================================
          # 2. 단일 방 조회
          # =========================================
          def get_room(request, _call)
            authorize!("student")

            room = ::Room.find(request.id)

            Bannote::Studyroomservice::Room::V1::GetRoomResponse.new(
              room: room_to_proto(room)
            )

          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room not found")
          end

          # =========================================
          # 3. 전체 방 목록
          # =========================================
          def list_rooms(_request, _call)
            authorize!("student")

            rooms = ::Room.all

            Bannote::Studyroomservice::Room::V1::ListRoomsResponse.new(
              rooms: rooms.map { |room| room_to_proto(room) }
            )
          end

          # =========================================
          # 4. 방 수정
          # =========================================
          def update_room(request, _call)
            authorize!("assistant")

            room = ::Room.find(request.id)

            room.update!(
              department_code: request.department_code.to_s,
              name: request.name,
              maximum_member: request.maximum_member,
              status: request.status
            )

            Bannote::Studyroomservice::Room::V1::UpdateRoomResponse.new(
              room: room_to_proto(room)
            )

          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room not found")
          rescue ActiveRecord::RecordInvalid => e
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # =========================================
          # 5. 방 삭제
          # =========================================
          def delete_room(request, _call)
            authorize!("assistant")

            room = ::Room.find(request.id)
            user_authority_level = SimulatedUserRoles.get_authority_level(Current.user_id)

            if user_authority_level >= SimulatedUserRoles::AUTHORITY_LEVELS["admin"] ||
               (user_authority_level >= SimulatedUserRoles::AUTHORITY_LEVELS["assistant"] &&
                room.created_by == Current.user_id)
              room.destroy!
            else
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Insufficient authority to delete this room."
              )
            end

            Bannote::Studyroomservice::Room::V1::DeleteRoomResponse.new

          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room not found")
          end

          # =========================================
          # 공통 메서드
          # =========================================
          private

          # 권한 검증 단축 메서드
          def authorize!(min_role)
            unless SimulatedUserRoles.has_authority?(
              Current.user_id,
              SimulatedUserRoles::AUTHORITY_LEVELS[min_role]
            )
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Requires #{min_role.capitalize} authority or higher."
              )
            end
          end

          # Room → Proto 변환
          def room_to_proto(room)
            Bannote::Studyroomservice::Room::V1::Room.new(
              id: room.id,
              department_code: room.department_code,
              name: room.name,
              maximum_member: room.maximum_member,
              status: room.status,
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
