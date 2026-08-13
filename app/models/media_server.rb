require "uri"

class MediaServer < ApplicationRecord
  PROVIDERS = { jellyfin: "jellyfin", plex: "plex" }.freeze

  has_many :server_connections, dependent: :restrict_with_error

  enum :provider, PROVIDERS, validate: true

  before_validation :normalize_base_url

  validates :name, :provider, :base_url, presence: true
  validates :base_url, uniqueness: { scope: :provider }
  validate :base_url_uses_http

  def self.configured
    first
  end

  private

  def normalize_base_url
    self.base_url = base_url.to_s.strip.chomp("/")
  end

  def base_url_uses_http
    uri = URI.parse(base_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present?

    errors.add(:base_url, "must be a complete HTTP or HTTPS URL")
  rescue URI::InvalidURIError
    errors.add(:base_url, "must be a complete HTTP or HTTPS URL")
  end
end
