class CreateListeningEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :listening_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :server_connection, null: false, foreign_key: true
      t.string :item_id, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :listening_events, %i[user_id occurred_at]
    add_index :listening_events, %i[user_id item_id occurred_at]
  end
end
