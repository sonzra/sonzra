class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :admin, :boolean, default: false, null: false

    execute <<~SQL.squish
      UPDATE users SET admin = TRUE
      WHERE id = (SELECT id FROM users ORDER BY created_at ASC, id ASC LIMIT 1)
    SQL
  end

  def down
    remove_column :users, :admin
  end
end
