class CreateSentences < ActiveRecord::Migration[8.1]
  def change
    create_table :sentences, id: false do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.references :language, type: :uuid, null: false, foreign_key: true, index: true
      t.text :text, null: false
      t.integer :audio_id
      t.string :source, null: false
      t.timestamps null: false
    end
    add_index :sentences, %i[language_id text], unique: true
  end
end
