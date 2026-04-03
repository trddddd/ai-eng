class CreateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :languages, id: false, if_not_exists: true do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.string :code, null: false
      t.string :name, null: false
      t.timestamps null: false
    end
    add_index :languages, :code, unique: true
  end
end
