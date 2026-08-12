class ServerConnection < ApplicationRecord
  encrypts :username, :password, :access_token

  belongs_to :user
  belongs_to :media_server
  has_many :listening_events, dependent: :destroy

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

  def client_options(remote_user_id: nil)
    { base_url: base_url, username: username, password: password, access_token: access_token.presence, remote_user_id: remote_user_id.presence }
  end
end
