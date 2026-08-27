class TrackSimilarity < ApplicationRecord
  belongs_to :server_connection

  validates :from_item_id, :to_item_id, :distance, presence: true
  validates :to_item_id, uniqueness: { scope: [ :server_connection_id, :from_item_id ] }

  def self.neighbors_for(connection, item_id, limit: 20)
    where(server_connection: connection, from_item_id: item_id.to_s)
      .order(distance: :asc)
      .limit(limit)
  end

  def self.prune_item!(connection, item_id)
    id_str = item_id.to_s
    where(server_connection: connection)
      .where("from_item_id = :id OR to_item_id = :id", id: id_str)
      .delete_all
  end
end
