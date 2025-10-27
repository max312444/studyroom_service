# grpc_service/service/room_exception_service.rb
# frozen_string_literal: true
require 'room_exception/room_exception_pb'
require 'room_exception/service_pb'
require 'room_exception/service_services_pb'
require 'concerns/current'
require 'concerns/simulated_user_roles'

module Bannote
  module Studyroomservice
    module Roomexception
      module V1
        class RoomExceptionServiceHandler < Bannote::Studyroomservice::Roomexception::V1::RoomExceptionService::Service
          def create_room_exception(request, _call)
            unless SimulatedUserRoles.has_authority?(Current.user_id, SimulatedUserRoles::AUTHORITY_LEVELS["assistant"])
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED, details: "Permission denied: Requires Assistant authority or higher to create room exceptions.")
            end

            # Check if room exists
            unless ::Room.exists?(request.room_id)
              _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room with ID #{request.room_id} not found.")
            end

            new_exception = ::RoomException.create!(
              room_id: request.room_id,
              holiday_date: request.holiday_date.to_date, # Assuming holiday_date is a string in YYYY-MM-DD format
              created_by: Current.user_id
            )

            Bannote::Studyroomservice::Roomexception::V1::CreateRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(new_exception)
            )
          rescue ActiveRecord::RecordInvalid => e
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: e.message)
          rescue ActiveRecord::RecordNotFound => e
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: e.message)
          rescue ArgumentError
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: "Invalid date format for holiday_date. Expected YYYY-MM-DD.")
          end

          def get_room_exception(request, _call)
            unless SimulatedUserRoles.has_authority?(Current.user_id, SimulatedUserRoles::AUTHORITY_LEVELS["student"])
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED, details: "Permission denied: Requires Student authority or higher to view room exceptions.")
            end
            exception = ::RoomException.find(request.id)

            Bannote::Studyroomservice::Roomexception::V1::GetRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(exception)
            )
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room exception not found")
          end

          def list_room_exceptions(request, _call)
            unless SimulatedUserRoles.has_authority?(Current.user_id, SimulatedUserRoles::AUTHORITY_LEVELS["student"])
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED, details: "Permission denied: Requires Student authority or higher to list room exceptions.")
            end
            exceptions = ::RoomException.all
            exceptions = exceptions.where(room_id: request.room_id) if request.room_id.present?

            Bannote::Studyroomservice::Roomexception::V1::ListRoomExceptionsResponse.new(
              room_exceptions: exceptions.map { |ex| room_exception_to_proto(ex) }
            )
          end

          def update_room_exception(request, _call)
            unless SimulatedUserRoles.has_authority?(Current.user_id, SimulatedUserRoles::AUTHORITY_LEVELS["assistant"])
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED, details: "Permission denied: Requires Assistant authority or higher to update room exceptions.")
            end

            exception = ::RoomException.find(request.id)

            exception.update!(
              room_id: request.room_id,
              holiday_date: request.holiday_date.to_date # Assuming holiday_date is a string in YYYY-MM-DD format
            )

            Bannote::Studyroomservice::Roomexception::V1::UpdateRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(exception)
            )
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room exception not found")
          rescue ActiveRecord::RecordInvalid => e
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: e.message)
          rescue ArgumentError
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: "Invalid date format for holiday_date. Expected YYYY-MM-DD.")
          end

          def delete_room_exception(request, _call)
            unless SimulatedUserRoles.has_authority?(Current.user_id, SimulatedUserRoles::AUTHORITY_LEVELS["admin"])
              _call.abort(GRPC::Core::StatusCodes::PERMISSION_DENIED, details: "Permission denied: Requires Admin authority or higher to delete room exceptions.")
            end
            exception = ::RoomException.find(request.id)
            exception.soft_delete

            Bannote::Studyroomservice::Roomexception::V1::DeleteRoomExceptionResponse.new
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Room exception not found")
          end

          private

          def room_exception_to_proto(exception)
            Bannote::Studyroomservice::Roomexception::V1::RoomException.new(
              id: exception.id,
              room_id: exception.room_id,
              holiday_date: Google::Protobuf::Timestamp.new(seconds: exception.holiday_date.to_time.to_i),
              created_at: Google::Protobuf::Timestamp.new(seconds: exception.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: exception.updated_at.to_i),
              created_by: exception.created_by
            )
          end
        end
      end
    end
  end
end