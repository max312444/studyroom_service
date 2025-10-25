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
                        puts "Received request to create room: #{request.name}"

                        Bannote::Studyroomservice::Room::V1::RoomResponse.new(
                            room_id: 1,
                            name: request.name,
                            capacity: request.capacity
                        )
                    end
                end
            end
        end
    end
end