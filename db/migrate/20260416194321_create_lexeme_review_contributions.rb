class CreateLexemeReviewContributions < ActiveRecord::Migration[8.1]
  def change
    create_table :lexeme_review_contributions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :review_log_id, null: false
      t.references :user, type: :bigint, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :lexeme_id, null: false
      t.uuid :sense_id
      t.uuid :context_family_id
      t.string :contribution_type, null: false

      t.datetime :created_at, null: false
    end

    add_foreign_key :lexeme_review_contributions, :review_logs, on_delete: :cascade
    add_foreign_key :lexeme_review_contributions, :lexemes, on_delete: :cascade
    add_foreign_key :lexeme_review_contributions, :senses, on_delete: :nullify
    add_foreign_key :lexeme_review_contributions, :context_families, on_delete: :nullify

    add_index :lexeme_review_contributions, :review_log_id, unique: true
    add_index :lexeme_review_contributions, %i[user_id lexeme_id]
    add_index :lexeme_review_contributions, %i[user_id contribution_type]
  end
end
