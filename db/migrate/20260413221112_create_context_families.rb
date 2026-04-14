class CreateContextFamilies < ActiveRecord::Migration[8.1]
  def change
    create_table :context_families, id: false do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :context_families, :name, unique: true
  end
end

