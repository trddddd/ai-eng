# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_16_194321) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cards", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "difficulty", default: 0.0, null: false
    t.datetime "due", null: false
    t.integer "elapsed_days", default: 0, null: false
    t.integer "lapses", default: 0, null: false
    t.datetime "last_review"
    t.datetime "mastered_at"
    t.integer "reps", default: 0, null: false
    t.integer "scheduled_days", default: 0, null: false
    t.uuid "sentence_occurrence_id", null: false
    t.float "stability", default: 0.0, null: false
    t.integer "state", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "due"], name: "index_cards_on_user_id_and_due"
    t.index ["user_id", "sentence_occurrence_id"], name: "index_cards_on_user_id_and_sentence_occurrence_id", unique: true
    t.index ["user_id", "state"], name: "index_cards_on_user_id_and_state"
  end

  create_table "context_families", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_context_families_on_name", unique: true
  end

  create_table "languages", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
  end

  create_table "lexeme_glosses", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "gloss", null: false
    t.uuid "lexeme_id", null: false
    t.uuid "target_language_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lexeme_id", "target_language_id", "gloss"], name: "index_lexeme_glosses_on_lexeme_target_lang_gloss", unique: true
    t.index ["lexeme_id"], name: "index_lexeme_glosses_on_lexeme_id"
    t.index ["target_language_id"], name: "index_lexeme_glosses_on_target_language_id"
  end

  create_table "lexeme_review_contributions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "context_family_id"
    t.string "contribution_type", null: false
    t.datetime "created_at", null: false
    t.uuid "lexeme_id", null: false
    t.uuid "review_log_id", null: false
    t.uuid "sense_id"
    t.bigint "user_id", null: false
    t.index ["review_log_id"], name: "index_lexeme_review_contributions_on_review_log_id", unique: true
    t.index ["user_id", "contribution_type"], name: "idx_on_user_id_contribution_type_8da46b0be9"
    t.index ["user_id", "lexeme_id"], name: "index_lexeme_review_contributions_on_user_id_and_lexeme_id"
    t.index ["user_id"], name: "index_lexeme_review_contributions_on_user_id"
  end

  create_table "lexemes", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "cefr_level"
    t.datetime "created_at", null: false
    t.string "headword", null: false
    t.uuid "language_id", null: false
    t.string "pos"
    t.datetime "updated_at", null: false
    t.index ["language_id", "headword"], name: "index_lexemes_on_language_id_and_headword", unique: true
    t.index ["language_id"], name: "index_lexemes_on_language_id"
  end

  create_table "review_logs", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.float "answer_accuracy"
    t.string "answer_text"
    t.integer "attempts", default: 1, null: false
    t.integer "backspace_count"
    t.uuid "card_id", null: false
    t.boolean "correct", null: false
    t.datetime "created_at", null: false
    t.integer "elapsed_ms"
    t.integer "rating", null: false
    t.string "recall_quality", null: false
    t.datetime "reviewed_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "reviewed_at"], name: "index_review_logs_on_card_id_and_reviewed_at"
  end

  create_table "senses", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "definition", null: false
    t.jsonb "examples", default: []
    t.integer "external_id"
    t.uuid "lexeme_id", null: false
    t.string "lexical_domain"
    t.string "pos", null: false
    t.integer "sense_rank", default: 1
    t.string "source", default: "wordnet", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_senses_on_external_id"
    t.index ["lexeme_id", "external_id"], name: "index_senses_on_lexeme_id_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["lexeme_id", "pos"], name: "index_senses_on_lexeme_id_and_pos"
    t.index ["lexeme_id"], name: "index_senses_on_lexeme_id"
  end

  create_table "sentence_occurrences", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "context_family_id"
    t.datetime "created_at", null: false
    t.string "form", null: false
    t.string "hint"
    t.uuid "lexeme_id", null: false
    t.uuid "sense_id"
    t.uuid "sentence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["context_family_id"], name: "index_sentence_occurrences_on_context_family_id"
    t.index ["lexeme_id"], name: "index_sentence_occurrences_on_lexeme_id"
    t.index ["sense_id"], name: "index_sentence_occurrences_on_sense_id"
    t.index ["sentence_id", "lexeme_id"], name: "index_sentence_occurrences_on_sentence_id_and_lexeme_id", unique: true
  end

  create_table "sentence_translations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "sentence_id", null: false
    t.uuid "target_language_id", null: false
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.index ["sentence_id", "target_language_id"], name: "idx_on_sentence_id_target_language_id_bfcb668ec7", unique: true
    t.index ["target_language_id"], name: "index_sentence_translations_on_target_language_id"
  end

  create_table "sentences", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.integer "audio_id"
    t.datetime "created_at", null: false
    t.uuid "language_id", null: false
    t.string "source", null: false
    t.integer "tatoeba_id"
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id", "text"], name: "index_sentences_on_language_id_and_text", unique: true
    t.index ["language_id"], name: "index_sentences_on_language_id"
    t.index ["tatoeba_id"], name: "index_sentences_on_tatoeba_id"
  end

  create_table "user_context_family_coverages", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "context_family_id", null: false
    t.datetime "created_at", null: false
    t.datetime "first_correct_at", null: false
    t.uuid "lexeme_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "lexeme_id", "context_family_id"], name: "idx_user_ctx_family_cov_on_user_lexeme_ctx_family", unique: true
    t.index ["user_id"], name: "index_user_context_family_coverages_on_user_id"
  end

  create_table "user_lexeme_states", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.integer "covered_family_count", default: 0, null: false
    t.integer "covered_sense_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.decimal "family_coverage_pct", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "last_covered_at"
    t.uuid "lexeme_id", null: false
    t.decimal "sense_coverage_pct", precision: 5, scale: 2, default: "0.0", null: false
    t.integer "total_family_count", default: 0, null: false
    t.integer "total_sense_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "lexeme_id"], name: "index_user_lexeme_states_on_user_id_and_lexeme_id", unique: true
    t.index ["user_id"], name: "index_user_lexeme_states_on_user_id"
  end

  create_table "user_sense_coverages", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "first_correct_at", null: false
    t.uuid "sense_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "sense_id"], name: "index_user_sense_coverages_on_user_id_and_sense_id", unique: true
    t.index ["user_id"], name: "index_user_sense_coverages_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "cards", "sentence_occurrences", on_delete: :restrict
  add_foreign_key "cards", "users", on_delete: :cascade
  add_foreign_key "lexeme_glosses", "languages", column: "target_language_id"
  add_foreign_key "lexeme_glosses", "lexemes"
  add_foreign_key "lexeme_review_contributions", "context_families", on_delete: :nullify
  add_foreign_key "lexeme_review_contributions", "lexemes", on_delete: :cascade
  add_foreign_key "lexeme_review_contributions", "review_logs", on_delete: :cascade
  add_foreign_key "lexeme_review_contributions", "senses", on_delete: :nullify
  add_foreign_key "lexeme_review_contributions", "users", on_delete: :cascade
  add_foreign_key "lexemes", "languages"
  add_foreign_key "review_logs", "cards", on_delete: :cascade
  add_foreign_key "senses", "lexemes", on_delete: :cascade
  add_foreign_key "sentence_occurrences", "context_families", on_delete: :restrict
  add_foreign_key "sentence_occurrences", "lexemes", on_delete: :restrict
  add_foreign_key "sentence_occurrences", "senses", on_delete: :restrict
  add_foreign_key "sentence_occurrences", "sentences", on_delete: :restrict
  add_foreign_key "sentence_translations", "languages", column: "target_language_id"
  add_foreign_key "sentence_translations", "sentences", on_delete: :restrict
  add_foreign_key "sentences", "languages"
  add_foreign_key "user_context_family_coverages", "context_families", on_delete: :cascade
  add_foreign_key "user_context_family_coverages", "lexemes", on_delete: :cascade
  add_foreign_key "user_context_family_coverages", "users", on_delete: :cascade
  add_foreign_key "user_lexeme_states", "lexemes", on_delete: :cascade
  add_foreign_key "user_lexeme_states", "users", on_delete: :cascade
  add_foreign_key "user_sense_coverages", "senses", on_delete: :cascade
  add_foreign_key "user_sense_coverages", "users", on_delete: :cascade
end
