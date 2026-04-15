class CreateSenses < ActiveRecord::Migration[8.1]
  def change
    create_table :senses, id: false do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.references :lexeme, type: :uuid, null: false,
                            foreign_key: { on_delete: :cascade }, index: true
      t.integer :external_id
      t.text :definition, null: false
      t.string :pos, null: false
      t.integer :sense_rank, default: 1
      t.jsonb :examples, default: []
      t.string :source, null: false, default: "wordnet"
      t.string :lexical_domain

      t.timestamps
    end

    add_index :senses, [:lexeme_id, :external_id], unique: true, where: "external_id IS NOT NULL"
    add_index :senses, :external_id
    add_index :senses, [:lexeme_id, :pos]
  end
end
