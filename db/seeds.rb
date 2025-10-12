# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Room.find_or_create_by!(name: "Room 1", capacity: 4)
Room.find_or_create_by!(name: "Room 2", capacity: 6)
# 샘플 스터디룸 데이터:
# 애플리케이션 테스트를 위해 두 개의 스터디룸을 생성합니다.
# find_or_create_by!를 사용하여 이미 존재하는 경우 다시 생성하지 않도록 합니다.