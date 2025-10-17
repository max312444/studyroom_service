require 'grpc'
require 'google/protobuf/timestamp_pb'
require 'google/protobuf/empty_pb'

# 생성된 proto 파일들을 로드합니다.
# 이 경로는 `grpc_tools_ruby_protoc`의 `--ruby_out` 및 `--grpc_out` 옵션과 일치해야 합니다。
$LOAD_PATH.unshift(File.expand_path('../grpc', __dir__)) # 생성된 gRPC 스텁 파일들을 로드하기 위해 경로를 추가합니다。

# 메시지 정의 파일들을 먼저 로드합니다.
require 'room/room_pb'
require 'reservation/reservation_pb'
require 'room_operating_hour/room_operating_hour_pb'
require 'room_exception/room_exception_pb'

# 서비스 정의 파일들을 로드합니다。
require 'room/service_services_pb'
require 'reservation/service_services_pb'
require 'room_operating_hour/service_services_pb'
require 'room_exception/service_services_pb'

# RoomService 구현
class RoomService < Studyroom::RoomService::Service
  # 스터디룸 생성
  def create_room(request, _call)
    room = Room.new(
      department_id: request.department_id,
      name: request.name,
      minimum_member: request.minimum_member,
      status: request.status # enum 값은 integer로 자동 변환됩니다.
    )
    if room.save
      Studyroom::Room.new(
        id: room.id,
        department_id: room.department_id,
        name: room.name,
        minimum_member: room.minimum_member,
        status: room.status_before_type_cast, # enum 값을 integer로 반환
        created_at: Google::Protobuf::Timestamp.new(seconds: room.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: room.updated_at.to_i)
      )
    else
      # 에러 처리 로직 (gRPC Status 코드를 사용하거나, 에러 메시지를 포함한 응답을 반환)
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, room.errors.full_messages.join(", "))
    end
  end

  # 특정 스터디룸 조회
  def get_room(request, _call)
    room = Room.find_by(id: request.id)
    unless room
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room not found")
    end
    Studyroom::Room.new(
      id: room.id,
      department_id: room.department_id,
      name: room.name,
      minimum_member: room.minimum_member,
      status: room.status_before_type_cast,
      created_at: Google::Protobuf::Timestamp.new(seconds: room.created_at.to_i),
      updated_at: Google::Protobuf::Timestamp.new(seconds: room.updated_at.to_i)
    )
  end

  # 모든 스터디룸 목록 조회
  def list_rooms(_request, _call)
    rooms = Room.all.map do |room|
      Studyroom::Room.new(
        id: room.id,
        department_id: room.department_id,
        name: room.name,
        minimum_member: room.minimum_member,
        status: room.status_before_type_cast,
        created_at: Google::Protobuf::Timestamp.new(seconds: room.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: room.updated_at.to_i)
      )
    end
    Studyroom::ListRoomsResponse.new(rooms: rooms)
  end

  # 스터디룸 정보 업데이트
  def update_room(request, _call)
    room = Room.find_by(id: request.id)
    unless room
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room not found")
    end

    room.department_id = request.department_id if request.department_id.present?
    room.name = request.name if request.name.present?
    room.minimum_member = request.minimum_member if request.minimum_member.present?
    room.status = request.status if request.status.present?

    if room.save
      Studyroom::Room.new(
        id: room.id,
        department_id: room.department_id,
        name: room.name,
        minimum_member: room.minimum_member,
        status: room.status_before_type_cast,
        created_at: Google::Protobuf::Timestamp.new(seconds: room.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: room.updated_at.to_i)
      )
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, room.errors.full_messages.join(", "))
    end
  end

  # 스터디룸 삭제
  def delete_room(request, _call)
    room = Room.find_by(id: request.id)
    unless room
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room not found")
    end
    room.destroy
    Google::Protobuf::Empty.new
  end
end

# ReservationService 구현
class ReservationService < Studyroom::ReservationService::Service
  # 예약 생성
  def create_reservation(request, _call)
    room = Room.find_by(id: request.room_id)
    raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room not found") unless room

    reservation = Reservation.new(
      room_id: request.room_id,
      group_id: request.group_id,
      link_id: request.link_id,
      start_time: request.start_time.to_time,
      end_time: request.end_time.to_time,
      purpose: request.purpose,
      priority: request.priority,
      created_by: request.created_by
    )
    if reservation.save
      Studyroom::Reservation.new(
        id: reservation.id,
        room_id: reservation.room_id,
        group_id: reservation.group_id,
        link_id: reservation.link_id,
        start_time: Google::Protobuf::Timestamp.new(seconds: reservation.start_time.to_i),
        end_time: Google::Protobuf::Timestamp.new(seconds: reservation.end_time.to_i),
        purpose: reservation.purpose,
        priority: reservation.priority_before_type_cast,
        created_by: reservation.created_by,
        updated_by: reservation.updated_by,
        deleted_by: reservation.deleted_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: reservation.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: reservation.updated_at.to_i),
        deleted_at: reservation.deleted_at ? Google::Protobuf::Timestamp.new(seconds: reservation.deleted_at.to_i) : nil
      )
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, reservation.errors.full_messages.join(", "))
    end
  end

  # 특정 예약 조회
  def get_reservation(request, _call)
    reservation = Reservation.find_by(id: request.id)
    unless reservation
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Reservation not found")
    end
    Studyroom::Reservation.new(
      id: reservation.id,
      room_id: reservation.room_id,
      group_id: reservation.group_id,
      link_id: reservation.link_id,
      start_time: Google::Protobuf::Timestamp.new(seconds: reservation.start_time.to_i),
      end_time: Google::Protobuf::Timestamp.new(seconds: reservation.end_time.to_i),
      purpose: reservation.purpose,
      priority: reservation.priority_before_type_cast,
      created_by: reservation.created_by,
      updated_by: reservation.updated_by,
      deleted_by: reservation.deleted_by,
      created_at: Google::Protobuf::Timestamp.new(seconds: reservation.created_at.to_i),
      updated_at: Google::Protobuf::Timestamp.new(seconds: reservation.updated_at.to_i),
      deleted_at: reservation.deleted_at ? Google::Protobuf::Timestamp.new(seconds: reservation.deleted_at.to_i) : nil
    )
  end

  # 예약 목록 조회
  def list_reservations(request, _call)
    reservations = Reservation.all
    reservations = reservations.where(room_id: request.room_id) if request.room_id.present?
    reservations = reservations.where("start_time >= ?", request.start_time_after.to_time) if request.start_time_after.present?
    reservations = reservations.where("end_time <= ?", request.end_time_before.to_time) if request.end_time_before.present?
    reservations = reservations.where(group_id: request.group_id) if request.group_id.present?

    reservations_proto = reservations.map do |reservation|
      Studyroom::Reservation.new(
        id: reservation.id,
        room_id: reservation.room_id,
        group_id: reservation.group_id,
        link_id: reservation.link_id,
        start_time: Google::Protobuf::Timestamp.new(seconds: reservation.start_time.to_i),
        end_time: Google::Protobuf::Timestamp.new(seconds: reservation.end_time.to_i),
        purpose: reservation.purpose,
        priority: reservation.priority_before_type_cast,
        created_by: reservation.created_by,
        updated_by: reservation.updated_by,
        deleted_by: reservation.deleted_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: reservation.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: reservation.updated_at.to_i),
        deleted_at: reservation.deleted_at ? Google::Protobuf::Timestamp.new(seconds: reservation.deleted_at.to_i) : nil
      )
    end
    Studyroom::ListReservationsResponse.new(reservations: reservations_proto)
  end

  # 예약 정보 업데이트
  def update_reservation(request, _call)
    reservation = Reservation.find_by(id: request.id)
    unless reservation
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Reservation not found")
    end

    # 업데이트할 필드만 설정
    reservation.room_id = request.room_id if request.room_id.present?
    reservation.group_id = request.group_id if request.group_id.present?
    reservation.link_id = request.link_id if request.link_id.present?
    reservation.start_time = request.start_time.to_time if request.start_time.present?
    reservation.end_time = request.end_time.to_time if request.end_time.present?
    reservation.purpose = request.purpose if request.purpose.present?
    reservation.priority = request.priority if request.priority.present?
    reservation.updated_by = request.updated_by if request.updated_by.present?

    if reservation.save
      Studyroom::Reservation.new(
        id: reservation.id,
        room_id: reservation.room_id,
        group_id: reservation.group_id,
        link_id: reservation.link_id,
        start_time: Google::Protobuf::Timestamp.new(seconds: reservation.start_time.to_i),
        end_time: Google::Protobuf::Timestamp.new(seconds: reservation.end_time.to_i),
        purpose: reservation.purpose,
        priority: reservation.priority_before_type_cast,
        created_by: reservation.created_by,
        updated_by: reservation.updated_by,
        deleted_by: reservation.deleted_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: reservation.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: reservation.updated_at.to_i),
        deleted_at: reservation.deleted_at ? Google::Protobuf::Timestamp.new(seconds: reservation.deleted_at.to_i) : nil
      )
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, reservation.errors.full_messages.join(", "))
    end
  end

  # 예약 삭제 (소프트 삭제)
  def delete_reservation(request, _call)
    reservation = Reservation.find_by(id: request.id)
    unless reservation
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Reservation not found")
    end
    # 소프트 삭제 시 deleted_by도 함께 업데이트
    if reservation.soft_delete(deleted_by: request.deleted_by)
      Google::Protobuf::Empty.new
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INTERNAL, "Failed to delete reservation")
    end
  end
end

# RoomOperatingHourService 구현
class RoomOperatingHourService < Studyroom::RoomOperatingHourService::Service
  # 스터디룸 운영 시간 생성
  def create_room_operating_hour(request, _call)
    room_operating_hour = RoomOperatingHour.new(
      room_id: request.room_id,
      day_of_week: request.day_of_week,
      opening_time: request.opening_time,
      closing_time: request.closing_time,
      day_maximum_time: request.day_maximum_time.present? ? request.day_maximum_time : nil
    )

    if room_operating_hour.save
      Studyroom::RoomOperatingHour.new(
        id: room_operating_hour.id,
        room_id: room_operating_hour.room_id,
        day_of_week: room_operating_hour.day_of_week,
        opening_time: room_operating_hour.opening_time.strftime("%H:%M"),
        closing_time: room_operating_hour.closing_time.strftime("%H:%M"),
        day_maximum_time: room_operating_hour.day_maximum_time ? room_operating_hour.day_maximum_time.strftime("%H:%M") : "",
        created_at: Google::Protobuf::Timestamp.new(seconds: room_operating_hour.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: room_operating_hour.updated_at.to_i),
        deleted_at: room_operating_hour.deleted_at ? Google::Protobuf::Timestamp.new(seconds: room_operating_hour.deleted_at.to_i) : nil
      )
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, room_operating_hour.errors.full_messages.join(", "))
    end
  end

  # 특정 스터디룸 운영 시간 조회
  def get_room_operating_hour(request, _call)
    room_operating_hour = RoomOperatingHour.find_by(id: request.id)
    unless room_operating_hour
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room operating hour not found")
    end
    Studyroom::RoomOperatingHour.new(
      id: room_operating_hour.id,
      room_id: room_operating_hour.room_id,
      day_of_week: room_operating_hour.day_of_week,
      opening_time: room_operating_hour.opening_time.strftime("%H:%M"),
      closing_time: room_operating_hour.closing_time.strftime("%H:%M"),
      day_maximum_time: room_operating_hour.day_maximum_time ? room_operating_hour.day_maximum_time.strftime("%H:%M") : "",
      created_at: Google::Protobuf::Timestamp.new(seconds: room_operating_hour.created_at.to_i),
      updated_at: Google::Protobuf::Timestamp.new(seconds: room_operating_hour.updated_at.to_i),
      deleted_at: room_operating_hour.deleted_at ? Google::Protobuf::Timestamp.new(seconds: room_operating_hour.deleted_at.to_i) : nil
    )
  end
  # 스터디룸 운영 시간 목록 조회
  def list_room_operating_hours(request, _call)
    room_operating_hours = RoomOperatingHour.all
    room_operating_hours = room_operating_hours.where(room_id: request.room_id) if request.room_id.present?
    room_operating_hours = room_operating_hours.where(day_of_week: request.day_of_week) if request.day_of_week.present?

    room_operating_hours_proto = room_operating_hours.map do |roh|
      Studyroom::RoomOperatingHour.new(
        id: roh.id,
        room_id: roh.room_id,
        day_of_week: roh.day_of_week,
        opening_time: roh.opening_time.strftime("%H:%M"),
        closing_time: roh.closing_time.strftime("%H:%M"),
        day_maximum_time: roh.day_maximum_time ? roh.day_maximum_time.strftime("%H:%M") : "",
        created_at: Google::Protobuf::Timestamp.new(seconds: roh.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: roh.updated_at.to_i),
        deleted_at: roh.deleted_at ? Google::Protobuf::Timestamp.new(seconds: roh.deleted_at.to_i) : nil
      )
    end
    Studyroom::ListRoomOperatingHoursResponse.new(room_operating_hours: room_operating_hours_proto)
  end

  # 스터디룸 운영 시간 정보 업데이트
  def update_room_operating_hour(request, _call)
    room_operating_hour = RoomOperatingHour.find_by(id: request.id)
    unless room_operating_hour
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room operating hour not found")
    end

    room_operating_hour.room_id = request.room_id if request.room_id.present?
    room_operating_hour.day_of_week = request.day_of_week if request.day_of_week.present?
    room_operating_hour.opening_time = request.opening_time if request.opening_time.present?
    room_operating_hour.closing_time = request.closing_time if request.closing_time.present?
    room_operating_hour.day_maximum_time = request.day_maximum_time if request.day_maximum_time.present?

    if room_operating_hour.save
      Studyroom::RoomOperatingHour.new(
        id: room_operating_hour.id,
        room_id: room_operating_hour.room_id,
        day_of_week: room_operating_hour.day_of_week,
        opening_time: room_operating_hour.opening_time.strftime("%H:%M"),
        closing_time: room_operating_hour.closing_time.strftime("%H:%M"),
        day_maximum_time: room_operating_hour.day_maximum_time ? room_operating_hour.day_maximum_time.strftime("%H:%M") : "",
        created_at: Google::Protobuf::Timestamp.new(seconds: room_operating_hour.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: room_operating_hour.updated_at.to_i),
        deleted_at: room_operating_hour.deleted_at ? Google::Protobuf::Timestamp.new(seconds: room_operating_hour.deleted_at.to_i) : nil
      )
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, room_operating_hour.errors.full_messages.join(", "))
    end
  end

  # 스터디룸 운영 시간 삭제 (소프트 삭제)
  def delete_room_operating_hour(request, _call)
    room_operating_hour = RoomOperatingHour.find_by(id: request.id)
    unless room_operating_hour
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room operating hour not found")
    end
    if room_operating_hour.soft_delete
      Google::Protobuf::Empty.new
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INTERNAL, "Failed to delete room operating hour")
    end
  end
end

# RoomExceptionService 구현
class RoomExceptionService < Studyroom::RoomExceptionService::Service
  # 스터디룸 예외 생성
  def create_room_exception(request, _call)
    room_exception = RoomException.new(
      room_id: request.room_id,
      holiday_date: Date.parse(request.holiday_date),
      reason: request.reason,
      opening_time: request.opening_time.present? ? Time.parse(request.opening_time) : nil,
      closing_time: request.closing_time.present? ? Time.parse(request.closing_time) : nil,
      created_by: request.created_by
    )
    if room_exception.save
      Studyroom::RoomException.new(
        id: room_exception.id,
        room_id: room_exception.room_id,
        holiday_date: room_exception.holiday_date.strftime("%Y-%m-%d"),
        reason: room_exception.reason,
        opening_time: room_exception.opening_time ? room_exception.opening_time.strftime("%H:%M") : "",
        closing_time: room_exception.closing_time ? room_exception.closing_time.strftime("%H:%M") : "",
        created_by: room_exception.created_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: room_exception.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: room_exception.updated_at.to_i)
      )
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, room_exception.errors.full_messages.join(", "))
    end
  end

  # 특정 스터디룸 예외 조회
  def get_room_exception(request, _call)
    room_exception = RoomException.find_by(id: request.id)
    unless room_exception
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room exception not found")
    end
    Studyroom::RoomException.new(
      id: room_exception.id,
      room_id: room_exception.room_id,
      holiday_date: room_exception.holiday_date.strftime("%Y-%m-%d"),
      reason: room_exception.reason,
      opening_time: room_exception.opening_time ? room_exception.opening_time.strftime("%H:%M") : "",
      closing_time: room_exception.closing_time ? room_exception.closing_time.strftime("%H:%M") : "",
      created_by: room_exception.created_by,
      created_at: Google::Protobuf::Timestamp.new(seconds: room_exception.created_at.to_i),
      updated_at: Google::Protobuf::Timestamp.new(seconds: room_exception.updated_at.to_i)
    )
  end

  # 스터디룸 예외 목록 조회
  def list_room_exceptions(request, _call)
    room_exceptions = RoomException.all
    room_exceptions = room_exceptions.where(room_id: request.room_id) if request.room_id.present?
    room_exceptions = room_exceptions.where(holiday_date: request.holiday_date) if request.holiday_date.present?

    room_exceptions_proto = room_exceptions.map do |re|
      Studyroom::RoomException.new(
        id: re.id,
        room_id: re.room_id,
        holiday_date: re.holiday_date.strftime("%Y-%m-%d"),
        reason: re.reason,
        opening_time: re.opening_time ? re.opening_time.strftime("%H:%M") : "",
        closing_time: re.closing_time ? re.closing_time.strftime("%H:%M") : "",
        created_by: re.created_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: re.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: re.updated_at.to_i)
      )
    end
    Studyroom::ListRoomExceptionsResponse.new(room_exceptions: room_exceptions_proto)
  end

  # 스터디룸 예외 정보 업데이트
  def update_room_exception(request, _call)
    room_exception = RoomException.find_by(id: request.id)
    unless room_exception
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room exception not found")
    end

    room_exception.room_id = request.room_id if request.room_id.present?
    room_exception.holiday_date = request.holiday_date if request.holiday_date.present?
    room_exception.reason = request.reason if request.reason.present?
    room_exception.opening_time = request.opening_time if request.opening_time.present?
    room_exception.closing_time = request.closing_time if request.closing_time.present?

    if room_exception.save
      Studyroom::RoomException.new(
        id: room_exception.id,
        room_id: room_exception.room_id,
        holiday_date: room_exception.holiday_date.strftime("%Y-%m-%d"),
        reason: room_exception.reason,
        opening_time: room_exception.opening_time ? room_exception.opening_time.strftime("%H:%M") : "",
        closing_time: room_exception.closing_time ? room_exception.closing_time.strftime("%H:%M") : "",
        created_by: room_exception.created_by,
        created_at: Google::Protobuf::Timestamp.new(seconds: room_exception.created_at.to_i),
        updated_at: Google::Protobuf::Timestamp.new(seconds: room_exception.updated_at.to_i)
      )
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, room_exception.errors.full_messages.join(", "))
    end
  end

  # 스터디룸 예외 삭제 (소프트 삭제)
  def delete_room_exception(request, _call)
    room_exception = RoomException.find_by(id: request.id)
    unless room_exception
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room exception not found")
    end
    if room_exception.soft_delete
      Google::Protobuf::Empty.new
    else
      raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INTERNAL, "Failed to delete room exception")
    end
  end
end

require 'grpc/reflection/v1alpha/reflection_pb'
require 'grpc/reflection/v1alpha/reflection_services_pb'

# gRPC 서버 시작 함수
def main
  # gRPC 서버 인스턴스 생성
  s = GRPC::RpcServer.new

  # 서버 주소 설정 (모든 인터페이스에서 50051 포트로 수신)
  s.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)

  # 리플렉션 서비스 활성화
  reflection_service = Grpc::Reflection::V1alpha::Reflection::Service.new
  s.handle(reflection_service)

  # 서비스 핸들러 등록
  s.handle(RoomService)
  s.handle(ReservationService)
  s.handle(RoomOperatingHourService)
  s.handle(RoomExceptionService)

  # 서버 시작
  s.run_till_terminated_or_interrupted(['int', 'SIGTERM'])
end

# Rails 환경에서 실행될 때만 서버를 시작하도록 합니다.
# 이 파일이 직접 실행될 때 (예: `rails runner app/services/grpc_server.rb`) 또는 별도의 스크립트에서 로드될 때 서버를 시작할 수 있습니다.
# 개발 환경에서는 Rails 서버와 별도로 gRPC 서버를 실행해야 합니다.
# 프로덕션 환경에서는 프로세스 관리자(예: systemd, Kubernetes)를 통해 관리됩니다.
if __FILE__ == $0
  # Rails 환경 로드 (필요시)
  require_relative '../../config/environment' # Rails 애플리케이션 로드

  # Rails 모델을 gRPC 서비스에서 사용하기 위해 Active Record를 초기화합니다.
  # 이 부분은 Rails 애플리케이션의 부트스트랩 과정에서 처리될 수도 있습니다.
  # 여기서는 독립적으로 실행될 경우를 대비하여 추가합니다.
  # ActiveRecord::Base.establish_connection(Rails.application.config.database_configuration[Rails.env])

  main
end