module WordMastery
  class InitializeState
    def self.call(...) = new(...).call

    def initialize(user:, lexeme:, now: Time.current)
      @user = user
      @lexeme = lexeme
      @now = now
    end

    def call
      UserLexemeState.find_or_create_by!(user: @user, lexeme: @lexeme) do |state|
        state.total_sense_count = @lexeme.senses.count
        state.total_family_count = unique_family_count
      end
    end

    private

    def unique_family_count
      SentenceOccurrence.where(lexeme: @lexeme)
                        .select(:context_family_id)
                        .distinct
                        .where.not(context_family_id: nil)
                        .count
    end
  end
end
