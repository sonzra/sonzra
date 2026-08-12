Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  namespace :admin do
    resource :registration_settings, only: %i[show update]
    resources :users, only: %i[index new create]
  end
  resources :passwords, param: :token
  root "home#index"
  get "offline_shell", to: "offline_shells#show", as: :offline_shell
  resources :offline_downloads, only: :index
  get "home/content", to: "home#content", as: :home_content
  get "library/artists", to: "library#artists", as: :library_artists
  get "library/albums", to: "library#albums", as: :library_albums
  get "library/audiobooks", to: "library#audiobooks", as: :library_audiobooks
  get "library/podcasts", to: "library#podcasts", as: :library_podcasts
  get "library/playlists", to: "library#playlists", as: :library_playlists
  get "library/recently-played", to: "library#recently_played", as: :library_recently_played
  get "library/most-played-songs", to: "library#most_played_songs", as: :library_most_played_songs
  get "library/recently-added-albums", to: "library#recently_added_albums", as: :library_recently_added_albums
  get "library/genres", to: "library#genres", as: :library_genres
  get "server_connections/:server_connection_id/artwork/:item_id", to: "artwork#show", as: :artwork_server_connection
  get "server_connections/:server_connection_id/audio/:item_id", to: "playback#show", as: :audio_server_connection
  get "server_connections/:server_connection_id/lyrics/:item_id", to: "lyrics#show", as: :lyrics_server_connection
  post "server_connections/:server_connection_id/playback_reports", to: "playback_reports#create", as: :playback_reports_server_connection
  post "server_connections/:server_connection_id/resume_items/:item_id/reset", to: "resume_items#reset", as: :reset_resume_server_connection
  get "server_connections/:server_connection_id/playback_queues/:item_id", to: "playback_queues#show", as: :playback_queue_server_connection
  get "server_connections/:server_connection_id/radio_tracks/:item_id", to: "radio_tracks#show", as: :radio_tracks_server_connection
  get "server_connections/:server_connection_id/library_items/:id", to: "library_items#show", as: :library_item_server_connection
  patch "server_connections/:server_connection_id/favorites/:item_id", to: "favorites#update", as: :favorite_server_connection
  get "server_connections/:server_connection_id/playlists", to: "playlists#index", as: :playlists_server_connection
  post "server_connections/:server_connection_id/playlists", to: "playlists#create"
  delete "server_connections/:server_connection_id/playlists/:id", to: "playlists#destroy", as: :playlist_server_connection
  post "server_connections/:server_connection_id/playlists/:playlist_id/items", to: "playlists#add_item", as: :playlist_items_server_connection
  delete "server_connections/:server_connection_id/playlists/:playlist_id/items/:entry_id", to: "playlists#remove_item", as: :playlist_item_server_connection
  resources :server_connections do
    get :quick_connect, on: :collection
    post :start_quick_connect, on: :collection
    get :quick_connect_status, on: :collection
    post :test_connection, on: :member
  end
  resource :player_preferences, only: :update
  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
