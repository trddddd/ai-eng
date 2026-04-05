class CreateSentenceOccurrences < ActiveRecord::Migration[8.1]
  def change
    create_table :sentence_occurrences, id: false do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.references :sentence, type: :uuid, null: false,
                              foreign_key: { on_delete: :restrict }, index: false
      t.references :lexeme, type: :uuid, null: false,
                            foreign_key: { on_delete: :restrict }, index: true
      t.string :form, null: false
      t.string :hint
      t.timestamps null: false
    end
    add_index :sentence_occurrences, %i[sentence_id lexeme_id], unique: true
  end
end
