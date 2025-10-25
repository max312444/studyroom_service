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
            puts "[Dummy] create_reservation called"
            Bannote::Studyroomservice::Reservation::V1::ReservationResponse.new(
              reservation_id: 1,
              room_id: request.room_id,
              user_id: request.user_id,
              status: "confirmed"
            )
          end
        end
      end
    end
  end
end
