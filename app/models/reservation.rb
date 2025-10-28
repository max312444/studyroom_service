class Reservation < ApplicationRecord
  # 예약 우선순위 정의: 낮음(low), 중간(medium), 높음(high)
  # ERD의 'priority' ENUM('우선1', '우선2', '우선3')에 해당하며, Rails에서는 integer 타입으로 저장됩니다.
  # enum priority: { low: 0, medium: 1, high: 2 }

  # 다른 모델과의 연관 관계 정의
  # Room 모델과 다대일 관계를 가집니다.
  belongs_to :room

  # Callbacks
  before_create :generate_code

  # 유효성 검사 (Validations)
  validates :code, presence: true, uniqueness: true
  # group_id, purpose, priority, created_by, start_time, end_time는 필수입니다.
  validates :group_id, presence: true
  validates :purpose, presence: true
  validates :priority, presence: true
  validates :created_by, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true

  # 예약 시간 유효성 검사: 시작 시간이 종료 시간보다 빨라야 합니다.
  validate :start_time_before_end_time

  # 예약 가능 여부 및 우선순위 처리 (생성 및 수정 전에 실행)
  before_validation :check_and_handle_reservation_conflicts, on: [:create, :update]

  # 소프트 삭제 (Soft Delete)
  # deleted_at 컬럼에 값이 있으면 삭제된 것으로 간주합니다.
  # 기본 스코프에서 deleted_at이 nil인 레코드만 조회하도록 설정합니다.
  default_scope { where(deleted_at: nil) }

  # 레코드를 "삭제"하는 대신 deleted_at에 현재 시간을 기록합니다.
  # deleted_by 인자를 받아 삭제자를 기록합니다.
  def soft_delete(deleted_by: nil)
    update(deleted_at: Time.current, deleted_by: deleted_by)
  end

  # 삭제된 레코드를 포함하여 모든 레코드를 조회할 때 사용합니다.
  def self.with_deleted
    unscope(where: :deleted_at)
  end

  private

  def generate_code
    self.code = SecureRandom.uuid
  end

  # 시작 시간이 종료 시간보다 빠른지 확인하는 커스텀 유효성 검사
  def start_time_before_end_time
    return unless start_time && end_time

    if start_time >= end_time
      errors.add(:start_time, "시작 시간은 종료 시간보다 빨라야 합니다.")
    end
  end

  # 예약 충돌 확인 및 우선순위 처리 로직
  def check_and_handle_reservation_conflicts
    # 1. 운영 시간 확인 (RoomOperatingHour, RoomException)
    unless is_available_during_operating_hours?
      errors.add(:base, "요청하신 시간은 스터디룸 운영 시간 범위에 포함되지 않거나 휴일입니다.")
      throw :abort
    end

    # 2. 기존 예약과의 충돌 확인
    conflicting_reservations = Reservation.where(room_id: room_id)
                                        .where.not(id: id) # 현재 예약 자신은 제외
                                        .where("start_time < ? AND end_time > ?", end_time, start_time)

    conflicting_reservations.each do |existing_reservation|
      if priority > existing_reservation.priority # 새 예약의 우선순위가 더 높은 경우
        existing_reservation.soft_delete # 기존 예약 강제 취소 (소프트 삭제)
      else # 새 예약의 우선순위가 낮거나 같은 경우
        errors.add(:base, "요청하신 시간에 이미 예약이 존재하며, 우선순위가 낮거나 같아 예약할 수 없습니다.")
        throw :abort # 예약 생성 중단
      end
    end
  end

  # 스터디룸 운영 시간 및 예외를 확인하여 예약 가능 여부를 반환합니다.
  def is_available_during_operating_hours?
    # 요일별 운영 시간 확인
    operating_hour = room.room_operating_hours.find_by(day_of_week: start_time.wday)

    # 운영 시간이 설정되지 않았거나 소프트 삭제된 경우 예약 불가
    return false if operating_hour.nil? || operating_hour.deleted_at.present?

    # 예약 시작/종료 시간을 'HH:MM' 형식으로 변환
    start_time_str = start_time.strftime('%H:%M')
    end_time_str = end_time.strftime('%H:%M')

    # 운영 시간도 'HH:MM' 형식으로 변환
    opening_time_str = operating_hour.opening_time.strftime('%H:%M')
    closing_time_str = operating_hour.closing_time.strftime('%H:%M')

    # 예약 시간이 운영 시간 내에 있는지 확인
    unless start_time_str >= opening_time_str && end_time_str <= closing_time_str
      return false
    end

    # 휴일 예외 확인
    room_exception = room.room_exceptions.find_by(holiday_date: start_time.to_date)

    if room_exception.present? && room_exception.deleted_at.nil?
      if room_exception.opening_time.present? && room_exception.closing_time.present?
        # 특별 운영 시간도 'HH:MM' 형식으로 변환
        exception_opening_time_str = room_exception.opening_time.strftime('%H:%M')
        exception_closing_time_str = room_exception.closing_time.strftime('%H:%M')

        # 예약 시간이 특별 운영 시간 내에 있는지 확인
        unless start_time_str >= exception_opening_time_str && end_time_str <= exception_closing_time_str
          return false
        end
      else
        # 특별 운영 시간이 없으면 휴일이므로 예약 불가
        return false
      end
    end

    true # 모든 조건을 통과하면 예약 가능
  end
end
