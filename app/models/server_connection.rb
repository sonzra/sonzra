class ServerConnection < ApplicationRecord
  encrypts :username, :password, :access_token

  belongs_to :user
  belongs_to :media_server
  has_many :listening_events, dependent: :destroy
  has_many :hidden_artists, dependent: :destroy
  has_many :hidden_genres, dependent: :destroy
  has_many :track_similarities, dependent: :destroy
  has_many :sonic_graph_nodes, dependent: :destroy

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

  def client_options(remote_user_id: nil, device_id: nil, access_token: nil, **options)
    token = access_token.presence || self.access_token.presence
    options_hash = {
      base_url: base_url,
      username: username,
      password: password,
      access_token: token,
      remote_user_id: remote_user_id.presence,
      device_id: device_id.presence
    }.compact

    if persisted? && !options.key?(:on_token_refreshed)
      options_hash[:on_token_refreshed] = ->(fresh_token) { update_column(:access_token, fresh_token) }
    end

    options_hash.merge(options)
  end
end
