module ContentBootstrap
  class ImportPoliglotGlosses < BaseOperation
    FILE = "poliglot-translations.json".freeze

    def call
      russian = Language.find_or_create_by!(code: "ru", name: "Russian")
      gloss_map = build_gloss_map
      lexeme_map = build_lexeme_map
      rows = build_rows(gloss_map, lexeme_map, russian.id)
      return unless rows.any?

      LexemeGloss.insert_all(rows, unique_by: :index_lexeme_glosses_on_lexeme_target_lang_gloss)
    end

    private

    def build_gloss_map
      data = load_json
      map = Hash.new { |h, k| h[k] = [] }
      data["data"].each do |entry|
        word = entry["1"].to_s.downcase.strip
        next if word.blank?

        map[word].concat(entry["3"].to_s.split("; ").map(&:strip).compact_blank)
      end
      map.each_value(&:uniq!)
      map
    end

    def build_lexeme_map
      english = Language.find_by!(code: "en")
      Lexeme.where(language: english)
            .pluck(:headword, :id)
            .each_with_object({}) { |(hw, id), h| h[hw.downcase.strip] = id }
    end

    def build_rows(gloss_map, lexeme_map, target_language_id)
      rows = []
      gloss_map.each do |word, glosses|
        lexeme_id = lexeme_map[word]
        next unless lexeme_id

        glosses.each do |gloss|
          rows << { lexeme_id:, target_language_id:, gloss:, created_at: now, updated_at: now }
        end
      end
      rows
    end

    def load_json
      raw = File.binread(data_path(FILE)).force_encoding("UTF-8").scrub
      data = JSON.parse(raw)
      raise "Invalid poliglot format: missing 'data' key" unless data.key?("data")

      data
    end
  end
end
