module ContentBootstrap
  class AssignFallbackSenses < BaseOperation
    def call
      language = Language.find_by!(code: "en")
      rows = []

      language.lexemes.find_each do |lexeme|
        next if lexeme.senses.any?

        rows << build_fallback_sense_row(lexeme.id, lexeme.headword, lexeme.pos)
      end

      Sense.insert_all(rows) if rows.any?
      log_results(rows, language.lexemes.count)
    end

    private

    def build_fallback_sense_row(lexeme_id, headword, pos)
      pos_string = pos.presence || "unknown"
      {
        lexeme_id:,
        external_id: nil,
        definition: fallback_definition(headword, pos_string),
        pos: pos_string,
        sense_rank: 1,
        examples: [],
        source: "fallback",
        lexical_domain: nil,
        created_at: now,
        updated_at: now
      }
    end

    def fallback_definition(headword, pos)
      case pos
      when "noun"
        "The word '#{headword}' (noun)"
      when "verb"
        "The action of '#{headword}' (verb)"
      when "adjective"
        "The quality of being '#{headword}' (adjective)"
      when "adverb"
        "The manner of '#{headword}' (adverb)"
      else
        "The word '#{headword}'"
      end
    end

    def log_results(rows, total_lexemes)
      fallback_count = rows.count
      percentage = (fallback_count.to_f / total_lexemes * 100).round(1)

      Rails.logger.info("AssignFallbackSenses: created #{fallback_count} fallback senses (#{percentage}% of lexemes)")
    end
  end
end
