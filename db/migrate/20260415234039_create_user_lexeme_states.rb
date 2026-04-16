class CreateUserLexemeStates < ActiveRecord::Migration[8.1]
  def change
    create_table :user_lexeme_states, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :bigint, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :lexeme_id, null: false
      t.integer :covered_sense_count, null: false, default: 0
      t.integer :total_sense_count, null: false, default: 0
      t.decimal :sense_coverage_pct, precision: 5, scale: 2, null: false, default: 0.0
      t.integer :covered_family_count, null: false, default: 0
      t.integer :total_family_count, null: false, default: 0
      t.decimal :family_coverage_pct, precision: 5, scale: 2, null: false, default: 0.0
      t.datetime :last_covered_at

      t.timestamps
    end

    add_foreign_key :user_lexeme_states, :lexemes, on_delete: :cascade
    add_index :user_lexeme_states, %i[user_id lexeme_id], unique: true
  end
end
