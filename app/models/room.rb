class Room < ApplicationRecord
  # 스터디룸 상태 정의: 공실(vacant) 또는 입실(occupied)
  # ERD의 'status' ENUM('공실', '입실')에 해당하며, Rails에서는 integer 타입으로 저장됩니다.

  # 이게 postman 테스트할 때 계속 문제라서 일단 주석처리함
  # 나중에 지문인식이나 얼굴인식으로 입실확인 하는거 넣으면 같이 추가하기로
  # enum status: { vacant: 0, occupied: 1 } 

  # 다른 모델과의 연관 관계 정의
  # RoomOperatingHour 모델과 일대다 관계를 가집니다.
  has_many :room_operating_hours
  # RoomException 모델과 일대다 관계를 가집니다。
  has_many :room_exceptions
  # Reservation 모델과 일대다 관계를 가집니다.
  has_many :reservations

  # 유효성 검사 (Validations)
  # name 컬럼은 필수이며, 최대 100자까지 허용합니다.
  validates :name, presence: true, length: { maximum: 100 }
  # minimum_member 컬럼은 필수이며, 0 이상의 정수만 허용합니다.
  validates :maximum_member, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # status 컬럼은 필수입니다.
  # validates :status, presence: true

  # department_id는 외부 서비스(유저 서비스)를 참조하므로,
  # 여기서는 데이터베이스 레벨의 외래 키 제약 조건은 추가하지 않습니다.
  # 유효성 검사는 애플리케이션 로직에서 처리하거나, 필요에 따라 추가할 수 있습니다.
  # validates :department_id, presence: true
end
