class AddTrackShareFieldsToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_reference :notifications, :media_server, foreign_key: true
    add_column :notifications, :notification_type, :string, null: false, default: "activity"
    add_column :notifications, :artist, :string
    add_column :notifications, :album, :string
    add_column :notifications, :item_id, :string
    add_column :notifications, :artwork_item_id, :string
    add_column :notifications, :note, :text
  end
end
