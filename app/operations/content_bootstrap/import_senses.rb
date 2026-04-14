require "wordnet"

module ContentBootstrap
  class ImportSenses < BaseOperation
    POS_MAPPING = {
      "noun" => :noun,
      "verb" => :verb,
      "adjective" => :adj,
      "adverb" => :adv,
      "modal verb" => :verb,
      "auxiliary verb" => :verb,
      "linking verb" => :verb,
      "pronoun" => nil,
      "preposition" => nil,
      "determiner" => :adj,
      "number" => :noun,
      "ordinal number" => :adj,
      "conjunction" => nil,
      "exclamation" => nil,
      "indefinite article" => nil,
      "definite article" => nil,
      "infinitive marker" => nil
    }.freeze

    def call
      lex = WordNet::Lexicon.new
      language = Language.find_by!(code: "en")
      rows = []

      language.lexemes.find_each do |lexeme|
        process_lexeme(lexeme, lex, rows)
      end

      Sense.insert_all(rows, unique_by: %i[lexeme_id external_id]) if rows.any?
      log_results(rows, language.lexemes.count)
    end

    private

    def process_lexeme(lexeme, lex, rows)
      synsets = filter_synsets(lex.lookup_synsets(lexeme.headword.downcase), map_pos(lexeme.pos))

      if synsets.empty?
        Rails.logger.warn("No WordNet match for lexeme: #{lexeme.headword} (pos: #{lexeme.pos || 'nil'})")
        return
      end

      synsets.each_with_index { |synset, index| rows << build_sense_row(lexeme.id, synset, index + 1) }
    end

    def filter_synsets(synsets, wordnet_pos)
      return synsets unless wordnet_pos

      pos_string = map_pos_symbol_to_string(wordnet_pos)
      synsets.select { |s| s.pos == pos_string }
    end

    def map_pos(pos)
      return nil if pos.blank?

      POS_MAPPING[pos]
    end

    def map_pos_symbol_to_string(pos)
      { noun: "n", verb: "v", adj: "a", adv: "r" }[pos]
    end

    def build_sense_row(lexeme_id, synset, sense_rank)
      {
        lexeme_id:,
        external_id: synset.synsetid,
        definition: synset.definition,
        pos: map_wordnet_pos_to_string(synset.pos),
        sense_rank:,
        examples: [],
        source: "wordnet",
        lexical_domain: synset.lexical_domain,
        created_at: now,
        updated_at: now
      }
    end

    def map_wordnet_pos_to_string(pos)
      return "unknown" unless pos

      # WordNet synset.pos returns string ("n", "v", "a", "r")
      case pos.to_s
      when "n" then "noun"
      when "v" then "verb"
      when "a" then "adjective"
      when "r" then "adverb"
      else "unknown"
      end
    end

    def log_results(rows, total_lexemes)
      matched_lexemes = rows.pluck(:lexeme_id).uniq.count
      skipped_lexemes = total_lexemes - matched_lexemes
      percentage = (matched_lexemes.to_f / total_lexemes * 100).round(1)

      Rails.logger.info("ImportSenses: matched #{matched_lexemes}/#{total_lexemes} lexemes (#{percentage}%)")
      Rails.logger.info("ImportSenses: skipped #{skipped_lexemes} lexemes (no WordNet match)")

      return unless skipped_lexemes > (total_lexemes * 0.2)

      Rails.logger.warn("ImportSenses: skipped >20% of lexemes - review POS mapping")
    end
  end
end
