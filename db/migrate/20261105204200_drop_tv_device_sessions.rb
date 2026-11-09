class DropTvDeviceSessions < ActiveRecord::Migration[8.1]
  def up
    drop_table :tv_device_sessions, if_exists: true
  end

  def down
    create_table :tv_device_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :device_id, null: false
      t.string :device_name, null: false
      t.string :token_digest, null: false, index: { unique: true }
      t.string :ip_address
      t.datetime :last_active_at
      t.timestamps
    end
  end
end
