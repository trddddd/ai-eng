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

ActiveRecord::Schema[8.1].define(version: 2026_04_04_000300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "sentence_occurrences", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "form", null: false
    t.string "hint"
    t.uuid "lexeme_id", null: false
    t.uuid "sentence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lexeme_id"], name: "index_sentence_occurrences_on_lexeme_id"
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
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id", "text"], name: "index_sentences_on_language_id_and_text", unique: true
    t.index ["language_id"], name: "index_sentences_on_language_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "lexeme_glosses", "languages", column: "target_language_id"
  add_foreign_key "lexeme_glosses", "lexemes"
  add_foreign_key "lexemes", "languages"
  add_foreign_key "sentence_occurrences", "lexemes", on_delete: :restrict
  add_foreign_key "sentence_occurrences", "sentences", on_delete: :restrict
  add_foreign_key "sentence_translations", "languages", column: "target_language_id"
  add_foreign_key "sentence_translations", "sentences", on_delete: :restrict
  add_foreign_key "sentences", "languages"
end
