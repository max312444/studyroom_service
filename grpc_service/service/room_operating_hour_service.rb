# grpc_service/service/room_operating_hour_service.rb
# frozen_string_literal: true

require 'room_operating_hour/room_operating_hour_pb'
require 'room_operating_hour/service_pb'
require 'room_operating_hour/service_services_pb'

# gRPC 환경에서는 Rails autoload가 동작하지 않으므로 직접 경로 지정
require_relative '../../app/models/concerns/current'
require_relative '../../app/models/concerns/simulated_user_roles'

module Bannote
  module Studyroomservice
    module Roomoperatinghour
      module V1
        class RoomOperatingHourServiceHandler < Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHourService::Service
          
          # 운영시간 생성
          def create_room_operating_hour(request, _call)
            unless SimulatedUserRoles.has_authority?(
              Current.user_id,
              SimulatedUserRoles::AUTHORITY_LEVELS["assistant"]
            )
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED,
                details: "Permission denied: Requires Assistant authority or higher to create room operating hours.")
            end

            begin
              opening_time = Time.parse(request.opening_time)
              closing_time = Time.parse(request.closing_time)
            rescue ArgumentError
              _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT,
                details: "Invalid time format for opening_time or closing_time. Expected HH:MM.")
            end

            if opening_time >= closing_time
              _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT,
                details: "Opening time must be before closing time.")
            end

            unless ::Room.exists?(request.room_id)
              _call.abort(GRPC::Core::StatusCodes::NOT_FOUND,
                details: "Room with ID #{request.room_id} not found.")
            end

            new_operating_hour = ::RoomOperatingHour.create!(
              room_id: request.room_id,
              day_of_week: request.day_of_week,
              opening_time: request.opening_time,
              closing_time: request.closing_time,
              created_by: Current.user_id
            )

            Bannote::Studyroomservice::Roomoperatinghour::V1::CreateRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(new_operating_hour)
            )

          rescue ActiveRecord::RecordInvalid => e
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: e.message)
          rescue ActiveRecord::RecordNotFound => e
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: e.message)
          end

          # 단일 조회
          def get_room_operating_hour(request, _call)
            unless SimulatedUserRoles.has_authority?(
              Current.user_id,
              SimulatedUserRoles::AUTHORITY_LEVELS["student"]
            )
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED,
                details: "Permission denied: Requires Student authority or higher to view room operating hours.")
            end

            operating_hour = ::RoomOperatingHour.find(request.id)
            Bannote::Studyroomservice::Roomoperatinghour::V1::GetRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(operating_hour)
            )
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room operating hour not found")
          end

          # 목록 조회
          def list_room_operating_hours(request, _call)
            unless SimulatedUserRoles.has_authority?(
              Current.user_id,
              SimulatedUserRoles::AUTHORITY_LEVELS["student"]
            )
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED,
                details: "Permission denied: Requires Student authority or higher to list room operating hours.")
            end

            operating_hours = ::RoomOperatingHour.all
            operating_hours = operating_hours.where(room_id: request.room_id) if request.room_id.present?

            Bannote::Studyroomservice::Roomoperatinghour::V1::ListRoomOperatingHoursResponse.new(
              room_operating_hours: operating_hours.map { |oh| room_operating_hour_to_proto(oh) }
            )
          end

          # 수정
          def update_room_operating_hour(request, _call)
            unless SimulatedUserRoles.has_authority?(
              Current.user_id,
              SimulatedUserRoles::AUTHORITY_LEVELS["assistant"]
            )
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED,
                details: "Permission denied: Requires Assistant authority or higher to update room operating hours.")
            end

            operating_hour = ::RoomOperatingHour.find(request.id)

            if request.opening_time.present? && request.closing_time.present?
              begin
                opening_time = Time.parse(request.opening_time)
                closing_time = Time.parse(request.closing_time)
              rescue ArgumentError
                _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT,
                  details: "Invalid time format for opening_time or closing_time. Expected HH:MM.")
              end

              if opening_time >= closing_time
                _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT,
                  details: "Opening time must be before closing time.")
              end
            end

            operating_hour.update!(
              room_id: request.room_id,
              day_of_week: request.day_of_week,
              opening_time: request.opening_time,
              closing_time: request.closing_time
            )

            Bannote::Studyroomservice::Roomoperatinghour::V1::UpdateRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(operating_hour)
            )
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room operating hour not found")
          rescue ActiveRecord::RecordInvalid => e
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: e.message)
          end

          # 삭제
          def delete_room_operating_hour(request, _call)
            unless SimulatedUserRoles.has_authority?(
              Current.user_id,
              SimulatedUserRoles::AUTHORITY_LEVELS["admin"]
            )
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED,
                details: "Permission denied: Requires Admin authority or higher to delete room operating hours.")
            end

            operating_hour = ::RoomOperatingHour.find(request.id)
            operating_hour.soft_delete

            Bannote::Studyroomservice::Roomoperatinghour::V1::DeleteRoomOperatingHourResponse.new
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room operating hour not found")
          end

          private

          def room_operating_hour_to_proto(operating_hour)
            Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHour.new(
              id: operating_hour.id,
              room_id: operating_hour.room_id,
              day_of_week: operating_hour.day_of_week,
              opening_time: operating_hour.opening_time.strftime("%H:%M"),
              closing_time: operating_hour.closing_time.strftime("%H:%M"),
              created_at: Google::Protobuf::Timestamp.new(seconds: operating_hour.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: operating_hour.updated_at.to_i),
              created_by: operating_hour.created_by
            )
          end
        end
      end
    end
  end
end
