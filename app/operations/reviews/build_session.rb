module Reviews
  class BuildSession
    BATCH_SIZE = 10

    PRELOAD_TREE = { sentence_occurrence: [
      { sentence: :sentence_translations },
      { lexeme: :lexeme_glosses }
    ] }.freeze

    def self.call(...) = new(...).call

    def initialize(user:, limit: BATCH_SIZE, now: Time.current)
      @user = user
      @limit = limit
      @now = now
    end

    def call
      return [] if @limit <= 0

      card_debt = fetch_card_debt
      remaining = @limit - card_debt.size
      return card_debt if remaining <= 0

      word_debt = fill_word_debt(remaining)
      card_debt + word_debt
    end

    private

    def fetch_card_debt
      Card.due_for_review(@user, now: @now)
          .order(due: :asc)
          .limit(@limit)
          .includes(PRELOAD_TREE)
          .to_a
    end

    def fill_word_debt(remaining)
      candidates = UserLexemeState
                   .where(user: @user)
                   .where(family_coverage_pct: ...FULL_COVERAGE)
                   .order(family_coverage_pct: :asc, last_covered_at: :asc)

      cards = []
      candidates.find_each do |uls|
        break if cards.size >= remaining

        card = create_word_debt_card(uls)
        cards << card if card
      end

      preload_associations(cards) if cards.any?
      cards
    end

    FULL_COVERAGE = 100.0
    private_constant :FULL_COVERAGE

    def create_word_debt_card(uls)
      excluded_ids = existing_occurrence_ids_for(uls.lexeme)

      occurrence = find_uncovered_occurrence(uls, column: :context_family_id, excluded_ids: excluded_ids,
                                                  covered_ids: covered_family_ids_for(uls)) ||
                   find_uncovered_occurrence(uls, column: :sense_id, excluded_ids: excluded_ids,
                                                  covered_ids: covered_sense_ids_for(uls))
      return unless occurrence

      Card.create!(
        user: @user,
        sentence_occurrence: occurrence,
        due: @now,
        state: Card::STATE_NEW
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def find_uncovered_occurrence(uls, column:, covered_ids:, excluded_ids:)
      SentenceOccurrence
        .where(lexeme: uls.lexeme)
        .where.not(column => nil)
        .where.not(column => covered_ids)
        .where.not(id: excluded_ids)
        .first
    end

    def covered_family_ids_for(uls)
      UserContextFamilyCoverage
        .where(user: @user, lexeme: uls.lexeme)
        .pluck(:context_family_id)
    end

    def covered_sense_ids_for(uls)
      UserSenseCoverage
        .joins(:sense)
        .merge(Sense.where(lexeme: uls.lexeme))
        .where(user: @user)
        .pluck(:sense_id)
    end

    def existing_occurrence_ids_for(lexeme)
      Card.where(user: @user)
          .joins(:sentence_occurrence)
          .where(sentence_occurrences: { lexeme_id: lexeme.id })
          .pluck(:sentence_occurrence_id)
    end

    def preload_associations(cards)
      ActiveRecord::Associations::Preloader.new(
        records: cards,
        associations: PRELOAD_TREE
      ).call
    end
  end
end
