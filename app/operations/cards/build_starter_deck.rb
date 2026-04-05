module Cards
  class BuildStarterDeck
    STARTER_DECK_SIZE = 50

    def self.call(user) = new(user).call

    def initialize(user)
      @user = user
    end

    def call
      occurrence_ids = fetch_occurrence_ids
      return if occurrence_ids.empty?

      Card.insert_all(build_rows(occurrence_ids), unique_by: %i[user_id sentence_occurrence_id])
    end

    private

    def build_rows(occurrence_ids)
      now = Time.current
      occurrence_ids.map { |id| build_row(id, now) }
    end

    def build_row(occurrence_id, now)
      {
        user_id: @user.id,
        sentence_occurrence_id: occurrence_id,
        due: now,
        stability: 0.0,
        difficulty: 0.0,
        elapsed_days: 0,
        scheduled_days: 0,
        reps: 0,
        lapses: 0,
        state: Card::STATE_NEW,
        last_review: nil,
        created_at: now,
        updated_at: now
      }
    end

    def fetch_occurrence_ids
      sql = <<~SQL.squish
        SELECT DISTINCT ON (so.lexeme_id) so.id
        FROM sentence_occurrences so
        JOIN lexemes l ON l.id = so.lexeme_id
        JOIN languages lang ON lang.id = l.language_id
        JOIN sentences s ON s.id = so.sentence_id
        JOIN sentence_translations st ON st.sentence_id = s.id
        JOIN languages tl ON tl.id = st.target_language_id
        WHERE l.cefr_level = 'a1'
          AND lang.code = 'en'
          AND tl.code = 'ru'
        ORDER BY so.lexeme_id, so.id
        LIMIT #{STARTER_DECK_SIZE}
      SQL
      ApplicationRecord.connection.select_values(sql)
    end
  end
end
