module Reviews
  class BuildSession
    BATCH_SIZE = 10

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
          .includes(sentence_occurrence: [
                      { sentence: :sentence_translations },
                      { lexeme: :lexeme_glosses }
                    ])
          .to_a
    end

    def fill_word_debt(remaining)
      candidates = UserLexemeState
                   .where(user: @user)
                   .where("family_coverage_pct < 100.0")
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

    def create_word_debt_card(uls)
      occurrence = find_uncovered_family_occurrence(uls) ||
                   find_uncovered_sense_occurrence(uls)
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

    def find_uncovered_family_occurrence(uls)
      covered_family_ids = UserContextFamilyCoverage
                           .where(user: @user, lexeme: uls.lexeme)
                           .pluck(:context_family_id)

      excluded_ids = existing_occurrence_ids_for(uls.lexeme)

      scope = SentenceOccurrence
              .where(lexeme: uls.lexeme)
              .where.not(context_family_id: nil)

      scope = scope.where.not(context_family_id: covered_family_ids) if covered_family_ids.any?
      scope = scope.where.not(id: excluded_ids) if excluded_ids.any?

      scope.first
    end

    def find_uncovered_sense_occurrence(uls)
      covered_sense_ids = UserSenseCoverage
                          .joins(:sense)
                          .merge(Sense.where(lexeme: uls.lexeme))
                          .where(user: @user)
                          .pluck(:sense_id)

      excluded_ids = existing_occurrence_ids_for(uls.lexeme)

      scope = SentenceOccurrence
              .where(lexeme: uls.lexeme)
              .where.not(sense_id: nil)

      scope = scope.where.not(sense_id: covered_sense_ids) if covered_sense_ids.any?
      scope = scope.where.not(id: excluded_ids) if excluded_ids.any?

      scope.first
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
        associations: { sentence_occurrence: [
          { sentence: :sentence_translations },
          { lexeme: :lexeme_glosses }
        ] }
      ).call
    end
  end
end
