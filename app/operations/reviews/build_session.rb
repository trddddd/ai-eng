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
      Card.due_for_review(@user, now: @now)
          .order(due: :asc)
          .limit(@limit)
          .includes(sentence_occurrence: [
                      { sentence: :sentence_translations },
                      { lexeme: :lexeme_glosses }
                    ])
    end
  end
end
