class RoomsController < ApplicationController
  def create
    room = Room.create(room_params)
    render json: room
  end

  def index
    render json: Room.all
  end

  private

  def room_params
    params.require(:room).permit(:name, :maximum_member)
  end
end
