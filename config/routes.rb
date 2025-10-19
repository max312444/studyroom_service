Rails.application.routes.draw do
  root to: ->(env) { [200, { "Content-Type" => "text/plain" }, ["Hello from Rails"]] }

  # RoomsController 연결
  resources :rooms, only: [:create, :index]
end
