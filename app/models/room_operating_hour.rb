class RoomOperatingHour < ApplicationRecord
  # Room 모델과 다대일 관계를 가집니다.
  belongs_to :room

  # 유효성 검사 (Validations)
  # room_id, day_of_week, opening_time, closing_time는 필수입니다.
  validates :room_id, presence: true
  validates :day_of_week, presence: true, numericality: { only_integer: true, in: 0..6 } # 0(일)부터 6(토)까지
  validates :opening_time, presence: true
  validates :closing_time, presence: true

  # 소프트 삭제 (Soft Delete)
  # deleted_at 컬럼에 값이 있으면 삭제된 것으로 간주합니다.
  default_scope { where(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def self.with_deleted
    unscope(where: :deleted_at)
  end
end