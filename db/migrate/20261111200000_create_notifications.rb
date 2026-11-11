class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :sender, foreign_key: { to_table: :users }
      t.references :media_server, foreign_key: true
      t.string :notification_type, null: false, default: "track_share"
      t.string :title, null: false
      t.string :artist
      t.string :album
      t.string :item_id, null: false
      t.string :artwork_item_id
      t.text :note
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :recipient_id, :read_at ]
    add_index :notifications, [ :recipient_id, :created_at ]
  end
end
