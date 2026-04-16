module WordMastery
  class RecordCoverage
    def self.call(...) = new(...).call

    def initialize(review_log:, now: Time.current)
      @review_log = review_log
      @now = now
    end

    def call
      return unless @review_log.correct

      card = @review_log.card
      occurrence = card.sentence_occurrence
      user = card.user
      lexeme = occurrence.lexeme

      ActiveRecord::Base.transaction do
        state = InitializeState.call(user: user, lexeme: lexeme, now: @now)

        record_sense_coverage(user, occurrence)
        record_family_coverage(user, lexeme, occurrence)

        recalculate!(state, user, lexeme)
      end
    end

    private

    def record_sense_coverage(user, occurrence)
      sense = occurrence.sense
      return if sense.nil?

      UserSenseCoverage.upsert(
        { user_id: user.id, sense_id: sense.id, first_correct_at: @now, created_at: @now, updated_at: @now },
        unique_by: %i[user_id sense_id]
      )
    end

    def record_family_coverage(user, lexeme, occurrence)
      family = occurrence.context_family
      return if family.nil?

      UserContextFamilyCoverage.upsert(
        {
          user_id: user.id, lexeme_id: lexeme.id,
          context_family_id: family.id, first_correct_at: @now,
          created_at: @now, updated_at: @now
        },
        unique_by: %i[user_id lexeme_id context_family_id]
      )
    end

    def recalculate!(state, user, lexeme)
      covered_senses = UserSenseCoverage.joins(:sense).where(user: user, senses: { lexeme_id: lexeme.id }).count
      total_senses = lexeme.senses.count

      covered_families = UserContextFamilyCoverage.where(user: user, lexeme: lexeme).count
      total_families = unique_family_count(lexeme)

      state.update!(
        covered_sense_count: covered_senses,
        total_sense_count: total_senses,
        sense_coverage_pct: coverage_pct(covered_senses, total_senses),
        covered_family_count: covered_families,
        total_family_count: total_families,
        family_coverage_pct: coverage_pct(covered_families, total_families),
        last_covered_at: @now
      )
    end

    def coverage_pct(covered, total)
      return 0.0 if total.zero?

      (covered.to_f / total * 100).round(2)
    end

    def unique_family_count(lexeme)
      SentenceOccurrence.where(lexeme: lexeme)
                        .select(:context_family_id)
                        .distinct
                        .where.not(context_family_id: nil)
                        .count
    end
  end
end
