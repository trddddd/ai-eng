class CreateLexemes < ActiveRecord::Migration[8.1]
  def change
    create_table :lexemes, id: false, if_not_exists: true do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.references :language, type: :uuid, null: false, foreign_key: true, index: true
      t.string :headword, null: false
      t.string :pos
      t.string :cefr_level
      t.timestamps null: false
    end
    add_index :lexemes, [:language_id, :headword], unique: true
  end
end
