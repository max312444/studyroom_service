# grpc_service/service/reservation_service.rb
# frozen_string_literal: true
require 'reservation/reservation_pb'
require 'reservation/service_pb'
require 'reservation/service_services_pb'

module Bannote
  module Studyroomservice
    module Reservation
      module V1
        class ReservationServiceHandler < Bannote::Studyroomservice::Reservation::V1::ReservationService::Service
          def create_reservation(request, _call)
            reservation = ::Reservation.new(
              room_id: request.room_id,
              group_id: request.group_id,
              link_id: request.link_id,
              start_time: request.start_time.to_time,
              end_time: request.end_time.to_time,
              purpose: request.purpose,
              priority: request.priority,
              created_by: 1 # 임시값, 인증 시스템 연동 필요
            )

            if reservation.save
              Bannote::Studyroomservice::Reservation::V1::CreateReservationResponse.new(
                reservation: reservation_to_proto(reservation)
              )
            else
              _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: reservation.errors.full_messages.join(", "))
            end
          end

          def get_reservation(request, _call)
            reservation = ::Reservation.find_by!(code: request.code)
            Bannote::Studyroomservice::Reservation::V1::GetReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Reservation not found")
          end

          def list_reservations(request, _call)
            reservations = ::Reservation.all
            reservations = reservations.where(room_id: request.room_id) if request.room_id.present?
            reservations = reservations.where("start_time >= ?", request.start_time_after.to_time) if request.start_time_after.present?
            reservations = reservations.where("end_time <= ?", request.end_time_before.to_time) if request.end_time_before.present?
            reservations = reservations.where(group_id: request.group_id) if request.group_id.present?

            Bannote::Studyroomservice::Reservation::V1::ListReservationsResponse.new(
              reservations: reservations.map { |r| reservation_to_proto(r) }
            )
          end

          def update_reservation(request, _call)
            reservation = ::Reservation.find_by!(code: request.code)
            reservation.update!(
              room_id: request.room_id,
              group_id: request.group_id,
              link_id: request.link_id,
              start_time: request.start_time.to_time,
              end_time: request.end_time.to_time,
              purpose: request.purpose,
              priority: request.priority,
              updated_by: 1 # 임시값, 인증 시스템 연동 필요
            )
            Bannote::Studyroomservice::Reservation::V1::UpdateReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Reservation not found")
          rescue ActiveRecord::RecordInvalid => e
            _call.abort(GRPC::Core::StatusCodes::INVALID_ARGUMENT, details: e.message)
          end

          def delete_reservation(request, _call)
            reservation = ::Reservation.find_by!(code: request.code)
            reservation.soft_delete(deleted_by: 1) # 임시값, 인증 시스템 연동 필요

            Bannote::Studyroomservice::Reservation::V1::DeleteReservationResponse.new(success: true)
          rescue ActiveRecord::RecordNotFound
            _call.abort(GRPC::Core::StatusCodes::NOT_FOUND, details: "Reservation not found")
          end

          private

          def reservation_to_proto(reservation)
            Bannote::Studyroomservice::Reservation::V1::Reservation.new(
              id: reservation.id,
              code: reservation.code,
              room_id: reservation.room_id,
              group_id: reservation.group_id,
              link_id: reservation.link_id,
              start_time: Google::Protobuf::Timestamp.new(seconds: reservation.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: reservation.end_time.to_i),
              purpose: reservation.purpose,
              priority: reservation.priority,
              created_at: Google::Protobuf::Timestamp.new(seconds: reservation.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: reservation.updated_at.to_i),
              deleted_at: reservation.deleted_at ? Google::Protobuf::Timestamp.new(seconds: reservation.deleted_at.to_i) : nil
            )
          end
        end
      end
    end
  end
end
