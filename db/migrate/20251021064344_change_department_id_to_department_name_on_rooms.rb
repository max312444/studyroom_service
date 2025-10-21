class ChangeDepartmentIdToDepartmentNameOnRooms < ActiveRecord::Migration[8.0]
  def change
    # 기존 외래키용 컬럼 제거
    remove_column :rooms, :department_id, :bigint if column_exists?(:rooms, :department_id)

    # 문자열 컬럼 추가
    add_column :rooms, :department_name, :string
  end
end
