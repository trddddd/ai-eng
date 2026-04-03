require "csv"

module ContentBootstrap
  class ImportNgslCoreLexemes < BaseOperation
    FILE = "ngsl-1-2.csv".freeze

    def call
      language = Language.find_or_create_by!(code: "en", name: "English")
      rows = parse_rows(language.id)
      Lexeme.insert_all(rows, unique_by: :index_lexemes_on_language_id_and_headword) if rows.any?
    end

    private

    def parse_rows(language_id)
      rows = []
      CSV.foreach(data_path(FILE), headers: false) do |row|
        next if row[0].to_s.start_with?("##")

        headword = normalize_headword(row[0].to_s)
        if headword.blank?
          Rails.logger.warn("Skipping blank headword in #{FILE}")
          next
        end
        rows << { language_id:, headword:, pos: nil, cefr_level: nil, created_at: now, updated_at: now }
      end
      rows
    end
  end
end
