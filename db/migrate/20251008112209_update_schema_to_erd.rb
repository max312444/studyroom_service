class UpdateSchemaToErd < ActiveRecord::Migration[8.0]
  def change
    # rooms 테이블 수정: ERD에 맞춰 스터디룸 정보를 업데이트합니다.
    remove_column :rooms, :capacity, :integer # 기존 capacity 컬럼 제거
    add_column :rooms, :department_id, :bigint # 학과 ID 컬럼 추가 (유저 서비스 참조)
    add_column :rooms, :minimum_member, :integer # 최소 인원 컬럼 추가
    add_column :rooms, :status, :integer # 방 상태 컬럼 추가 (공실/입실, enum으로 모델에서 처리)

    # reservations 테이블 수정: ERD에 맞춰 예약 정보를 업데이트합니다.
    remove_column :reservations, :user_name, :string # 기존 user_name 컬럼 제거
    add_column :reservations, :group_id, :bigint, null: false # 그룹 ID 컬럼 추가 (그룹 단위 예약)
    add_column :reservations, :link_id, :bigint # 외부 일정 서비스 연동을 위한 링크 ID 컬럼 추가
    add_column :reservations, :purpose, :string, null: false # 예약 사유 컬럼 추가
    add_column :reservations, :priority, :integer, null: false # 예약 우선순위 컬럼 추가 (enum으로 모델에서 처리)
    add_column :reservations, :created_by, :bigint, null: false # 예약 생성자 ID 컬럼 추가
    add_column :reservations, :updated_by, :bigint # 예약 수정자 ID 컬럼 추가
    add_column :reservations, :deleted_by, :bigint # 예약 삭제자 ID 컬럼 추가
    add_column :reservations, :deleted_at, :datetime # 소프트 삭제를 위한 deleted_at 컬럼 추가

    # room_operating_hours 테이블 생성: 요일별 스터디룸 운영 시간을 관리합니다.
    create_table :room_operating_hours do |t|
      t.references :room, null: false, foreign_key: true # Room 테이블 참조
      t.integer :day_of_week, limit: 1, null: false # 요일 (0:일요일 ~ 6:토요일)
      t.time :opening_time, null: false # 여는 시간
      t.time :closing_time, null: false # 닫는 시간
      t.time :day_maximum_time # 요일별 최대 예약 시간
      t.datetime :deleted_at # 소프트 삭제를 위한 deleted_at 컬럼

      t.timestamps # created_at, updated_at 자동 추가
    end

    # room_exceptions 테이블 생성: 스터디룸의 비정기적 휴일 또는 특별 운영 시간을 관리합니다.
    create_table :room_exceptions do |t|
      t.references :room, null: false, foreign_key: true # Room 테이블 참조
      t.date :holiday_date, null: false # 휴일 날짜
      t.string :reason, limit: 100 # 휴일 사유
      t.time :opening_time # 일회성 여는 시간
      t.time :closing_time # 일회성 닫는 시간
      t.bigint :created_by, null: false # 설정한 사용자 ID

      t.timestamps # created_at, updated_at 자동 추가
    end

    # 외래 키 인덱스 추가: 조인 성능 향상을 위해 인덱스를 추가합니다.
    add_index :rooms, :department_id # rooms 테이블의 department_id에 인덱스 추가
    add_index :reservations, :group_id # reservations 테이블의 group_id에 인덱스 추가
    add_index :reservations, :link_id # reservations 테이블의 link_id에 인덱스 추가
    add_index :room_operating_hours, :day_of_week # room_operating_hours 테이블의 day_of_week에 인덱스 추가
    add_index :room_exceptions, :holiday_date # room_exceptions 테이블의 holiday_date에 인덱스 추가
  end
