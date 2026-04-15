module ContentBootstrap
  class AssignContextFamilies < BaseOperation
    LEXICAL_DOMAIN_TO_FAMILY = {
      # people & relationships
      "noun.person" => "people & relationships",
      "noun.group" => "people & relationships",
      "verb.social" => "people & relationships",

      # communication
      "noun.communication" => "communication",
      "verb.communication" => "communication",

      # body & health
      "noun.body" => "body & health",
      "verb.body" => "body & health",

      # food & drink
      "noun.food" => "food & drink",
      "verb.consumption" => "food & drink",

      # movement & sports
      "verb.motion" => "movement & sports",
      "verb.competition" => "movement & sports",

      # thinking & knowledge
      "noun.cognition" => "thinking & knowledge",
      "verb.cognition" => "thinking & knowledge",

      # emotions & feelings
      "noun.feeling" => "emotions & feelings",
      "verb.emotion" => "emotions & feelings",
      "noun.motive" => "emotions & feelings",

      # objects & tools
      "noun.artifact" => "objects & tools",

      # nature & environment
      "noun.animal" => "nature & environment",
      "noun.plant" => "nature & environment",
      "noun.substance" => "nature & environment",
      "noun.object" => "nature & environment",
      "noun.phenomenon" => "nature & environment",

      # places & travel
      "noun.location" => "places & travel",

      # time & events
      "noun.time" => "time & events",
      "noun.event" => "time & events",
      "verb.change" => "time & events",

      # actions & activities
      "noun.act" => "actions & activities",
      "verb.creation" => "actions & activities",

      # possession & commerce
      "noun.possession" => "possession & commerce",
      "verb.possession" => "possession & commerce",

      # physical interaction
      "verb.contact" => "physical interaction",
      "verb.perception" => "physical interaction",

      # weather
      "verb.weather" => "weather",

      # qualities & states
      "noun.attribute" => "qualities & states",
      "noun.state" => "qualities & states",
      "noun.process" => "qualities & states",
      "noun.shape" => "qualities & states",
      "noun.quantity" => "qualities & states",
      "noun.Tops" => "qualities & states",
      "noun.relation" => "qualities & states"
    }.freeze

    def call # rubocop:disable Metrics/MethodLength
      families = ContextFamily.all.index_by(&:name)
      updates_with_sense = []
      updates_without_sense = []
      skipped = 0

      incomplete_occurrences.includes(:sense, lexeme: :senses).find_each(batch_size: 1000) do |occurrence|
        result = classify_occurrence(occurrence, families)
        if result.nil?
          skipped += 1
        elsif result[:sense_id]
          updates_with_sense << result
        else
          updates_without_sense << result
        end
      end

      flush_updates(updates_with_sense, updates_without_sense)
      log_results(updates_with_sense.size + updates_without_sense.size, skipped)
    end

    private

    def classify_occurrence(occurrence, families)
      sense = occurrence.sense || occurrence.lexeme.senses.min_by(&:sense_rank)
      return nil if sense.nil?

      family_name = map_lexical_domain_to_family(sense.lexical_domain) || "unknown"
      families[family_name] ||= ContextFamily.create!(name: family_name, description: fallback_description(family_name))
      base = { id: occurrence.id, context_family_id: families[family_name].id }
      occurrence.sense_id.nil? ? base.merge(sense_id: sense.id) : base
    end

    def flush_updates(updates_with_sense, updates_without_sense)
      # Batch UPDATE grouped by (sense_id, context_family_id) — one query per unique combination
      updates_with_sense.group_by { |u| [u[:sense_id], u[:context_family_id]] }.each do |(sense_id, cf_id), rows|
        SentenceOccurrence.where(id: rows.map { |r| r[:id] }).update_all(sense_id:, context_family_id: cf_id)
      end

      # Batch UPDATE grouped by context_family_id — at most 17 queries (one per family)
      updates_without_sense.group_by { |u| u[:context_family_id] }.each do |cf_id, rows|
        SentenceOccurrence.where(id: rows.map { |r| r[:id] }).update_all(context_family_id: cf_id)
      end
    end

    def incomplete_occurrences
      SentenceOccurrence.where(sense_id: nil)
                        .or(SentenceOccurrence.where(context_family_id: nil))
    end

    def map_lexical_domain_to_family(lexical_domain)
      return nil if lexical_domain.blank?

      LEXICAL_DOMAIN_TO_FAMILY[lexical_domain]
    end

    def fallback_description(family_name)
      family_name == "unknown" ? "Fallback: прилагательные/наречия, function words" : "#{family_name} context family"
    end

    def log_results(assigned, skipped_no_sense)
      Rails.logger.info("AssignContextFamilies: assigned #{assigned} occurrences")
      Rails.logger.info("AssignContextFamilies: skipped #{skipped_no_sense} (no sense for lexeme)")
    end
  end
end
