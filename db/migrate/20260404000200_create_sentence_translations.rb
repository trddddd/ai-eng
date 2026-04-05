class CreateSentenceTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :sentence_translations, id: false do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.references :sentence, type: :uuid, null: false,
                              foreign_key: { on_delete: :restrict }, index: false
      t.references :target_language, type: :uuid, null: false,
                                     foreign_key: { to_table: :languages }, index: true
      t.text :text, null: false
      t.timestamps null: false
    end
    add_index :sentence_translations, %i[sentence_id target_language_id], unique: true
  end
end
