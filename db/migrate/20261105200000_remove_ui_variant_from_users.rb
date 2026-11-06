class RemoveUiVariantFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :ui_variant, :string, null: false, default: "legacy"
  end
end
