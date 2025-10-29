# frozen_string_literal: true

require 'reservation/reservation_pb'
require 'reservation/service_pb'
require 'reservation/service_services_pb'

require_relative '../../app/models/concerns/current'
require_relative '../../app/models/concerns/simulated_user_roles'

module Bannote
  module Studyroomservice
    module Reservation
      module V1
        class ReservationServiceHandler < Bannote::Studyroomservice::Reservation::V1::ReservationService::Service
          
          # =========================================
          # 1. 예약 생성
          # =========================================
          def create_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.new(
              room_id: request.room_id,
              group_id: request.group_id,
              link_id: request.link_id,
              start_time: request.start_time.to_time,
              end_time: request.end_time.to_time,
              purpose: request.purpose,
              priority: request.priority,
              created_by: Current.user_id
            )

            reservation.save!
            Bannote::Studyroomservice::Reservation::V1::CreateReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordInvalid => e
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # =========================================
          # 2. 예약 조회
          # =========================================
          def get_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            Bannote::Studyroomservice::Reservation::V1::GetReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Reservation not found")
          end

          # =========================================
          # 3. 예약 목록 조회
          # =========================================
          def list_reservations(request, _call)
            authorize!("student")

            reservations = ::Reservation.all
            reservations = reservations.where(room_id: request.room_id) if request.room_id.present?
            reservations = reservations.where("start_time >= ?", request.start_time_after.to_time) if request.start_time_after.present?
            reservations = reservations.where("end_time <= ?", request.end_time_before.to_time) if request.end_time_before.present?
            reservations = reservations.where(group_id: request.group_id) if request.group_id.present?

            Bannote::Studyroomservice::Reservation::V1::ListReservationsResponse.new(
              reservations: reservations.map { |r| reservation_to_proto(r) }
            )
          end

          # =========================================
          # 4. 예약 수정
          # =========================================
          def update_reservation(request, _call)
            reservation = ::Reservation.find_by!(code: request.code)
            user_authority_level = SimulatedUserRoles.get_authority_level(Current.user_id)

            unless can_modify?(reservation, user_authority_level)
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Insufficient authority to update this reservation."
              )
            end

            reservation.update!(
              room_id: request.room_id,
              group_id: request.group_id,
              link_id: request.link_id,
              start_time: request.start_time.to_time,
              end_time: request.end_time.to_time,
              purpose: request.purpose,
              priority: request.priority,
              updated_by: Current.user_id
            )

            Bannote::Studyroomservice::Reservation::V1::UpdateReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Reservation not found")
          rescue ActiveRecord::RecordInvalid => e
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # =========================================
          # 5. 예약 삭제
          # =========================================
          def delete_reservation(request, _call)
            reservation = ::Reservation.find_by!(code: request.code)
            user_authority_level = SimulatedUserRoles.get_authority_level(Current.user_id)

            unless can_modify?(reservation, user_authority_level)
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Insufficient authority to delete this reservation."
              )
            end

            reservation.update!(deleted_at: Time.now, deleted_by: Current.user_id)

            Bannote::Studyroomservice::Reservation::V1::DeleteReservationResponse.new(success: true)
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Reservation not found")
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

          # 수정 / 삭제 가능 여부 판정
          def can_modify?(reservation, user_level)
            return true if user_level >= SimulatedUserRoles::AUTHORITY_LEVELS["assistant"]
            return true if user_level >= SimulatedUserRoles::AUTHORITY_LEVELS["student"] &&
                           reservation.created_by == Current.user_id
            false
          end

          # Reservation → Proto 변환
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
              deleted_at: reservation.deleted_at ? Google::Protobuf::Timestamp.new(seconds: reservation.deleted_at.to_i) : nil,
              created_by: reservation.created_by
            )
          end
        end
      end
    end
  end
end
