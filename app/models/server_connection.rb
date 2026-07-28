require "uri"

class ServerConnection < ApplicationRecord
  PROVIDERS = { jellyfin: "jellyfin" }.freeze

  encrypts :username, :password

  enum :provider, PROVIDERS, validate: true

  before_validation :normalize_base_url

  validates :name, :provider, :base_url, :username, presence: true
  validates :password, presence: true, on: :create
  validates :name, uniqueness: true
  validate :base_url_uses_http

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
