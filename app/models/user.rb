class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :server_connections, dependent: :destroy
  has_many :recommendation_collections, dependent: :destroy
  has_many :recommendation_runs, dependent: :destroy
  has_many :listening_events, dependent: :destroy
  has_many :hidden_artists, dependent: :destroy
  has_many :hidden_genres, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient
  has_many :sent_notifications, class_name: "Notification", foreign_key: :sender_id, dependent: :nullify, inverse_of: :sender
  belongs_to :preferred_server_connection, class_name: "ServerConnection", optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  generates_token_for :api_token

  validates :email_address, presence: true

  before_create :assign_administrator_role, if: :first_user?
  after_create :lock_registrations_if_first_admin, if: :admin?

  private

  def first_user?
    User.where.not(id: id).none?
  end

  def assign_administrator_role
    self.admin = true
    @was_first_user = true
  end

  def lock_registrations_if_first_admin
    return unless @was_first_user
    return if ENV["SONZRA_OPEN_REGISTRATION"] == "true"

    ApplicationSetting.instance.update!(registrations_enabled: false)
  end
end
