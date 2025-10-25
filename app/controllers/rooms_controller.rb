class RoomsController < ApplicationController
  # 전체 조회
  def index
    render json: Room.all
  end

  # 단건 조회
  def show
    room = Room.find(params[:id])
    render json: room
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Room not found' }, status: :not_found
  end

  # 생성
  def create
    room = Room.new(room_params)
    if room.save
      render json: room, status: :created
    else
      render json: room.errors, status: :unprocessable_entity
    end
  end

  # 수정
  def update
    room = Room.find(params[:id])
    if room.update(room_params)
      render json: room
    else
      render json: room.errors, status: :unprocessable_entity
    end
  end

  # 삭제
  def destroy
    room = Room.find(params[:id])
    room.destroy
    render json: { message: 'Room deleted successfully' }
  end

  private

  def room_params
    params.permit(:name, :maximum_member)
  end
end
