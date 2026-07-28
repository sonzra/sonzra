class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :server_connections, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  before_create :assign_administrator_role, if: :first_user?
  after_create_commit :claim_legacy_server_connections, if: :first_user?

  private

  def first_user?
    User.where.not(id: id).none?
  end

  def assign_administrator_role
    self.admin = true
  end

  def claim_legacy_server_connections
    ServerConnection.where(user_id: nil).update_all(user_id: id, updated_at: Time.current)
  end
end
