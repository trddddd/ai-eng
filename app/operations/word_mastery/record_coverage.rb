module WordMastery
  class RecordCoverage
    def self.call(...) = new(...).call

    def initialize(review_log:, now: Time.current)
      @review_log = review_log
      @now = now
    end

    def call
      return unless @review_log.correct
      return if LexemeReviewContribution.exists?(review_log_id: @review_log.id)

      card = @review_log.card
      @occurrence = card.sentence_occurrence
      @user = card.user
      @lexeme = @occurrence.lexeme

      state = InitializeState.call(user: @user, lexeme: @lexeme, now: @now)
      contribution_type = compute_contribution_type

      create_contribution(contribution_type)
      record_sense_coverage
      record_family_coverage

      recalculate!(state)
    end

    # Maps (sense_is_new, family_is_new) → contribution_type per ASM-03 truth table.
    CONTRIBUTION_TYPE_BY_NEWNESS = {
      [true, true] => "new_sense_and_family",
      [true, false] => "new_sense",
      [false, true] => "new_family",
      [false, false] => "reinforcement"
    }.freeze

    private

    def compute_contribution_type
      key = [sense_new?, family_new?]
      CONTRIBUTION_TYPE_BY_NEWNESS.fetch(key)
    end

    def sense_new?
      sense = @occurrence.sense
      return false if sense.nil?

      !UserSenseCoverage.exists?(user: @user, sense: sense)
    end

    def family_new?
      family = @occurrence.context_family
      return false if family.nil?

      !UserContextFamilyCoverage.exists?(user: @user, lexeme: @lexeme, context_family: family)
    end

    def create_contribution(contribution_type)
      LexemeReviewContribution.create!(
        review_log_id: @review_log.id,
        user_id: @user.id,
        lexeme_id: @lexeme.id,
        sense_id: @occurrence.sense&.id,
        context_family_id: @occurrence.context_family&.id,
        contribution_type: contribution_type,
        created_at: @now
      )
    end

    def record_sense_coverage
      sense = @occurrence.sense
      return if sense.nil?

      UserSenseCoverage.upsert(
        { user_id: @user.id, sense_id: sense.id, first_correct_at: @now, created_at: @now, updated_at: @now },
        unique_by: %i[user_id sense_id]
      )
    end

    def record_family_coverage
      family = @occurrence.context_family
      return if family.nil?

      UserContextFamilyCoverage.upsert(
        {
          user_id: @user.id, lexeme_id: @lexeme.id,
          context_family_id: family.id, first_correct_at: @now,
          created_at: @now, updated_at: @now
        },
        unique_by: %i[user_id lexeme_id context_family_id]
      )
    end

    def recalculate!(state)
      covered_senses = UserSenseCoverage.joins(:sense).where(user: @user, senses: { lexeme_id: @lexeme.id }).count
      total_senses = @lexeme.senses.count

      covered_families = UserContextFamilyCoverage.where(user: @user, lexeme: @lexeme).count
      total_families = unique_family_count

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

    def unique_family_count
      SentenceOccurrence.where(lexeme: @lexeme)
                        .select(:context_family_id)
                        .distinct
                        .where.not(context_family_id: nil)
                        .count
    end
  end
end
