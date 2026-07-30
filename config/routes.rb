Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  namespace :admin do
    resource :registration_settings, only: %i[show update]
  end
  resources :passwords, param: :token
  root "home#index"
  get "home/content", to: "home#content", as: :home_content
  get "library/artists", to: "library#artists", as: :library_artists
  get "library/albums", to: "library#albums", as: :library_albums
  get "library/audiobooks", to: "library#audiobooks", as: :library_audiobooks
  get "library/podcasts", to: "library#podcasts", as: :library_podcasts
  get "library/genres", to: "library#genres", as: :library_genres
  get "server_connections/:server_connection_id/artwork/:item_id", to: "artwork#show", as: :artwork_server_connection
  get "server_connections/:server_connection_id/audio/:item_id", to: "playback#show", as: :audio_server_connection
  post "server_connections/:server_connection_id/playback_reports", to: "playback_reports#create", as: :playback_reports_server_connection
  post "server_connections/:server_connection_id/resume_items/:item_id/reset", to: "resume_items#reset", as: :reset_resume_server_connection
  get "server_connections/:server_connection_id/playback_queues/:item_id", to: "playback_queues#show", as: :playback_queue_server_connection
  get "server_connections/:server_connection_id/library_items/:id", to: "library_items#show", as: :library_item_server_connection
  resources :server_connections do
    post :test_connection, on: :member
  end
  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
