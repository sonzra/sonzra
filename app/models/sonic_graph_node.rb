class SonicGraphNode < ApplicationRecord
  CURRENT_ANALYSIS_VERSION = "v5"

  belongs_to :server_connection

  validates :item_id, :title, presence: true
  validates :item_id, uniqueness: { scope: :server_connection_id }

  scope :with_analysis_version, ->(version) { where(analysis_version: version) }
  scope :current_analysis, -> { with_analysis_version(CURRENT_ANALYSIS_VERSION) }
end
