class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :server_connections, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true

  before_create :assign_administrator_role, if: :first_user?

  private

  def first_user?
    User.where.not(id: id).none?
  end

  def assign_administrator_role
    self.admin = true
  end
end
