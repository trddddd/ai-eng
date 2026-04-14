module Sentences
  # rubocop:disable Metrics/ClassLength
  class ImportTatoeba
    EN_LANG_CODE = "eng".freeze
    RU_LANG_CODE = "rus".freeze
    BATCH_SIZE = 500

    def self.call = new.call

    def call
      preload_languages!
      check_lexemes!
      lexeme_lookup = build_lexeme_lookup

      eng_sentences, rus_sentences = parse_sentences_file
      eng_to_rus_text = build_translation_mapping(eng_sentences.keys.to_set, rus_sentences)
      import_batches(eng_sentences, eng_to_rus_text, lexeme_lookup)
    end

    private

    def preload_languages!
      @en = Language.find_by!(code: "en")
      @ru = find_or_create_language("ru", "Russian")
    end

    def find_or_create_language(code, name)
      Language.find_or_create_by!(code: code, name: name)
    rescue ActiveRecord::RecordNotUnique
      Language.find_by!(code: code)
    end

    def check_lexemes!
      # rubocop:disable Rails/Exit
      abort "No lexemes in DB. Run content_bootstrap:import_all first" if Lexeme.none?
      # rubocop:enable Rails/Exit
    end

    def build_lexeme_lookup
      Lexeme.pluck(:id, :headword).to_h { |id, hw| [hw.downcase, id] }
    end

    def sentences_file = Rails.root.join("db/data/tatoeba/sentences.csv")
    def links_file = Rails.root.join("db/data/tatoeba/links.csv")

    def parse_sentences_file
      return [{}, {}] unless sentences_file.exist?

      eng = {}
      rus = {}
      CSV.foreach(sentences_file, col_sep: "\t") do |row|
        tatoeba_id, lang, text = row
        next unless tatoeba_id && lang && text

        id = tatoeba_id.to_i
        case lang
        when EN_LANG_CODE then eng[id] = text
        when RU_LANG_CODE then rus[id] = text
        end
      end
      [eng, rus]
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def build_translation_mapping(eng_id_set, rus_sentences)
      return {} unless links_file.exist?

      mapping = {}
      CSV.foreach(links_file, col_sep: "\t") do |row|
        id1_str, id2_str = row
        next unless id1_str && id2_str

        id1 = id1_str.to_i
        id2 = id2_str.to_i
        if eng_id_set.include?(id1) && rus_sentences.key?(id2)
          mapping[id1] ||= rus_sentences[id2]
        elsif eng_id_set.include?(id2) && rus_sentences.key?(id1)
          mapping[id2] ||= rus_sentences[id1]
        end
      end
      mapping
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def import_batches(eng_sentences, eng_to_rus_text, lexeme_lookup)
      # Only import English sentences that have a Russian translation
      importable = eng_sentences.select { |id, _| eng_to_rus_text.key?(id) }

      imported = 0
      now = Time.current
      importable.each_slice(BATCH_SIZE) do |slice|
        insert_batch(slice, eng_to_rus_text, lexeme_lookup, now)
        imported += slice.size
        # rubocop:disable Rails/Output
        puts "Processed #{imported}/#{importable.size} sentences" if (imported % 10_000).zero?
        # rubocop:enable Rails/Output
      end
      # rubocop:disable Rails/Output
      puts "ImportTatoeba done: #{imported} English sentences with Russian translations processed"
      # rubocop:enable Rails/Output
    end

    def insert_batch(slice, eng_to_rus_text, lexeme_lookup, now)
      ApplicationRecord.transaction do
        sentence_rows = slice.map do |tatoeba_id, text|
          { language_id: @en.id, text:, source: "tatoeba", tatoeba_id:, created_at: now, updated_at: now }
        end
        Sentence.insert_all(sentence_rows, unique_by: :index_sentences_on_language_id_and_text)

        texts = slice.map { |_, text| text }
        text_to_id = Sentence.where(language_id: @en.id, text: texts).pluck(:text, :id).to_h

        insert_translations(slice, eng_to_rus_text, text_to_id, now)
        insert_occurrences(slice, text_to_id, lexeme_lookup, now)
      end
    end

    def insert_translations(slice, eng_to_rus_text, text_to_id, now)
      rows = slice.filter_map do |tatoeba_id, text|
        rus_text = eng_to_rus_text[tatoeba_id]
        db_id = text_to_id[text]
        next unless rus_text && db_id

        { sentence_id: db_id, target_language_id: @ru.id, text: rus_text, created_at: now, updated_at: now }
      end
      SentenceTranslation.insert_all(rows, unique_by: %i[sentence_id target_language_id]) if rows.any?
    end

    def insert_occurrences(slice, text_to_id, lexeme_lookup, now)
      rows = slice.filter_map do |_tatoeba_id, text|
        db_id = text_to_id[text]
        next unless db_id

        result = find_lexeme(text, lexeme_lookup)
        next unless result

        lexeme_id, form = result
        { sentence_id: db_id, lexeme_id:, form:, created_at: now, updated_at: now }
      end
      return unless rows.any?

      SentenceOccurrence.insert_all(rows, unique_by: :index_sentence_occurrences_on_sentence_id_and_lexeme_id)
    end

    def find_lexeme(text, lexeme_lookup)
      downcased = text.downcase
      candidates = lexeme_lookup.select { |hw, _| word_boundaries_regex(hw).match?(downcased) }
      return nil if candidates.empty?

      best_hw, best_id = candidates.min_by do |hw, id|
        [-hw.length, downcased.index(word_boundaries_regex(hw)), hw, id.to_s]
      end

      form = text.match(word_boundaries_regex(best_hw))&.to_s
      form ? [best_id, form] : nil
    end

    def word_boundaries_regex(headword)
      Regexp.new("\\b#{Regexp.escape(headword)}\\b", Regexp::IGNORECASE)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
