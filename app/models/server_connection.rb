class ServerConnection < ApplicationRecord
  encrypts :username, :password, :access_token

  belongs_to :user
  belongs_to :media_server
  has_many :listening_events, dependent: :destroy
  has_many :hidden_artists, dependent: :destroy
  has_many :hidden_genres, dependent: :destroy
  has_many :track_similarities, dependent: :delete_all
  has_many :sonic_graph_nodes, dependent: :delete_all
  has_many :recommendation_runs, dependent: :destroy
  has_many :recommendation_collections, dependent: :destroy
  has_many :preferred_by_users, class_name: "User", foreign_key: "preferred_server_connection_id", dependent: :nullify

  after_create_commit -> { BuildSonicGraphJob.perform_later(id) }

  validates :username, presence: true
  validates :access_token, presence: true, unless: :password?
  validates :user_id, uniqueness: { scope: :media_server_id }
  validates_associated :media_server

  # Keeps the connection aggregate convenient to construct while persisting
  # shared server settings exclusively on MediaServer.
  %i[name provider base_url].each do |attribute|
    define_method(attribute) { media_server&.public_send(attribute) }
    define_method("#{attribute}=") do |value|
      self.media_server ||= MediaServer.new
      media_server.public_send("#{attribute}=", value)
    end
  end

  def client_options(remote_user_id: nil, device_id: nil)
    { base_url: base_url, username: username, password: password, access_token: access_token.presence, remote_user_id: remote_user_id.presence, device_id: device_id.presence }.compact
  end
end
