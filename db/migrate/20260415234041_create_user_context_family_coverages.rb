class CreateUserContextFamilyCoverages < ActiveRecord::Migration[8.1]
  def change
    create_table :user_context_family_coverages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :bigint, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :lexeme_id, null: false
      t.uuid :context_family_id, null: false
      t.datetime :first_correct_at, null: false

      t.timestamps
    end

    add_foreign_key :user_context_family_coverages, :lexemes, on_delete: :cascade
    add_foreign_key :user_context_family_coverages, :context_families, on_delete: :cascade
    add_index :user_context_family_coverages, %i[user_id lexeme_id context_family_id],
              unique: true, name: "idx_user_ctx_family_cov_on_user_lexeme_ctx_family"
  end
end
