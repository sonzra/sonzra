class CreateApplicationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :application_settings do |t|
      t.boolean :registrations_enabled, default: true, null: false

      t.timestamps
    end
  end
end
