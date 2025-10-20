Rails.application.routes.draw do
  root to: ->(env) { [200, { "Content-Type" => "text/plain" }, ["Hello from Rails"]] }

  # 방 관련
  resources :rooms, only: [:create, :index]

  # 예약 관련
  resources :reservations

  # 운영 시간 관련
  resources :room_operating_hours

  # 예외(휴일, 점검 등) 관련
  resources :room_exceptions
end
