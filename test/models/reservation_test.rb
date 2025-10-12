require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  # 테스트에 사용할 기본 room, 운영 시간, 예외 데이터를 설정합니다.
  setup do
    @room = rooms(:one) # test/fixtures/rooms.yml 에 정의된 :one Room
    
    # 월요일(1) 9시-18시 운영 시간 설정
    @operating_hour = RoomOperatingHour.create!(
      room: @room,
      day_of_week: 1,
      opening_time: Time.parse("09:00"),
      closing_time: Time.parse("18:00")
    )
    
    # 특정 날짜(다음 주 월요일)를 휴일로 설정
    @next_monday = Date.today.next_occurring(:monday)
    @exception_date = @next_monday + 1.week
    RoomException.create!(
      room: @room,
      holiday_date: @exception_date,
      reason: "Maintenance",
      created_by: 1
    )
  end

  # 1. 정상적인 예약 생성 테스트
  test "should create reservation if within operating hours and no conflicts" do
    reservation_time = @next_monday.to_time.change(hour: 10)
    reservation = Reservation.new(
      room: @room,
      start_time: reservation_time,
      end_time: reservation_time + 1.hour,
      group_id: 1,
      purpose: "Team Meeting",
      priority: :medium,
      created_by: 1
    )
    assert reservation.save, "예약이 생성되어야 합니다: #{reservation.errors.full_messages.join(", ")}"
  end

  # 2. 운영 시간 외 예약 시도 테스트 (실패)
  test "should not create reservation outside of operating hours" do
    reservation_time = @next_monday.to_time.change(hour: 8) # 9시 이전
    reservation = Reservation.new(
      room: @room,
      start_time: reservation_time,
      end_time: reservation_time + 1.hour,
      group_id: 1,
      purpose: "Early Meeting",
      priority: :medium,
      created_by: 1
    )
    assert_not reservation.save, "운영 시간 외에는 예약이 실패해야 합니다."
    assert_includes reservation.errors[:base], "요청하신 시간은 스터디룸 운영 시간 범위에 포함되지 않거나 휴일입니다."
  end

  # 3. 휴일 예약 시도 테스트 (실패)
  test "should not create reservation on a holiday" do
    reservation_time = @exception_date.to_time.change(hour: 10)
    reservation = Reservation.new(
      room: @room,
      start_time: reservation_time,
      end_time: reservation_time + 1.hour,
      group_id: 1,
      purpose: "Holiday Meeting",
      priority: :medium,
      created_by: 1
    )
    assert_not reservation.save, "휴일에는 예약이 실패해야 합니다."
    assert_includes reservation.errors[:base], "요청하신 시간은 스터디룸 운영 시간 범위에 포함되지 않거나 휴일입니다."
  end

  # 4. 기존 예약과 시간이 겹칠 때 우선순위가 낮은 경우 테스트 (실패)
  test "should not create reservation if time conflicts and priority is lower" do
    # 먼저 기준이 되는 예약을 생성
    base_time = @next_monday.to_time.change(hour: 11)
    Reservation.create!(
      room: @room,
      start_time: base_time,
      end_time: base_time + 1.hour,
      group_id: 1,
      purpose: "High Prio Meeting",
      priority: :high,
      created_by: 1
    )
    
    # 우선순위가 낮은 새 예약을 시도
    new_reservation = Reservation.new(
      room: @room,
      start_time: base_time + 30.minutes,
      end_time: base_time + 90.minutes,
      group_id: 2,
      purpose: "Low Prio Meeting",
      priority: :low,
      created_by: 2
    )
    
    assert_not new_reservation.save, "우선순위가 낮으면 중복 예약이 실패해야 합니다."
    assert_includes new_reservation.errors[:base], "요청하신 시간에 이미 예약이 존재하며, 우선순위가 낮거나 같아 예약할 수 없습니다."
  end

  # 5. 기존 예약과 시간이 겹칠 때 우선순위가 높은 경우 테스트 (성공 및 기존 예약 취소)
  test "should create reservation and cancel existing one if priority is higher" do
    # 먼저 우선순위가 낮은 예약을 생성
    base_time = @next_monday.to_time.change(hour: 14)
    existing_reservation = Reservation.create!(
      room: @room,
      start_time: base_time,
      end_time: base_time + 1.hour,
      group_id: 1,
      purpose: "Low Prio Meeting",
      priority: :low,
      created_by: 1
    )
    
    # 우선순위가 높은 새 예약을 시도
    new_reservation = Reservation.new(
      room: @room,
      start_time: base_time + 30.minutes,
      end_time: base_time + 90.minutes,
      group_id: 2,
      purpose: "High Prio Meeting",
      priority: :high,
      created_by: 2
    )
    
    assert new_reservation.save, "우선순위가 높으면 예약이 성공해야 합니다: #{new_reservation.errors.full_messages.join(", ")}"
    
    # 기존 예약이 soft-delete 되었는지 확인
    assert_not_nil existing_reservation.reload.deleted_at, "기존 예약은 soft-delete 되어야 합니다."
  end

  # 6. 시작 시간이 종료 시간보다 늦는 경우 테스트 (실패)
  test "should not create reservation if start_time is after end_time" do
    reservation_time = @next_monday.to_time.change(hour: 10)
    reservation = Reservation.new(
      room: @room,
      start_time: reservation_time + 1.hour,
      end_time: reservation_time,
      group_id: 1,
      purpose: "Invalid Time",
      priority: :medium,
      created_by: 1
    )
    assert_not reservation.save, "시작 시간이 종료 시간보다 늦으면 예약이 실패해야 합니다."
    assert_includes reservation.errors[:start_time], "시작 시간은 종료 시간보다 빨라야 합니다."
  end
end