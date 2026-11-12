class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :actor_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :title, null: false
      t.string :message, null: false
      t.string :link_url
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :user_id, :read_at ]
    add_index :notifications, [ :user_id, :created_at ]
  end
end
