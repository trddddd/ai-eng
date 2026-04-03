class CreateLexemeGlosses < ActiveRecord::Migration[8.1]
  def change
    create_table :lexeme_glosses, id: false, if_not_exists: true do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.references :lexeme, type: :uuid, null: false, foreign_key: true, index: true
      t.references :target_language, type: :uuid, null: false,
                   foreign_key: { to_table: :languages }, index: true
      t.text :gloss, null: false
      t.timestamps null: false
    end
    add_index :lexeme_glosses, [:lexeme_id, :target_language_id, :gloss], unique: true,
              name: "index_lexeme_glosses_on_lexeme_target_lang_gloss"
  end
end
