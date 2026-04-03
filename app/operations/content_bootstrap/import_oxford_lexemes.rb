require "csv"

module ContentBootstrap
  class ImportOxfordLexemes < BaseOperation
    FILE = "oxford-5000.csv".freeze

    def call
      language = Language.find_or_create_by!(code: "en", name: "English")
      rows = parse_rows(language.id)
      Lexeme.insert_all(rows, unique_by: :index_lexemes_on_language_id_and_headword) if rows.any?
    end

    private

    def parse_rows(language_id)
      rows = []
      CSV.foreach(data_path(FILE), headers: true) do |row|
        headword = normalize_headword(row["word"].to_s)
        if headword.blank?
          Rails.logger.warn("Skipping blank headword in #{FILE}")
          next
        end
        rows << build_row(language_id, headword, row["pos"].presence, row["level"].presence)
      end
      rows
    end

    def build_row(language_id, headword, pos, cefr_level)
      { language_id:, headword:, pos:, cefr_level:, created_at: now, updated_at: now }
    end
  end
end
