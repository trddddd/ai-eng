module Reviews
  class RecordAnswer
    def self.call(...) = new(...).call

    # rubocop:disable Metrics/ParameterLists
    def initialize(card:, correct:, answer_text: nil, elapsed_ms: nil,
                   attempts: 1, backspace_count: nil, now: Time.current)
      # rubocop:enable Metrics/ParameterLists
      @card = card
      @correct = correct
      @answer_text = answer_text
      @elapsed_ms = elapsed_ms
      @attempts = attempts
      @backspace_count = backspace_count
      @now = now
    end

    # rubocop:disable Metrics/MethodLength
    def call
      accuracy = ReviewLog.compute_accuracy(@answer_text, @card.form)
      recall   = ReviewLog.classify_recall(
        correct: @correct, elapsed_ms: @elapsed_ms, answer_accuracy: accuracy
      )
      rating = ReviewLog.compute_rating(recall)

      ActiveRecord::Base.transaction do
        review_log = @card.review_logs.create!(
          rating: rating,
          recall_quality: recall,
          correct: @correct,
          answer_text: @answer_text,
          answer_accuracy: accuracy,
          elapsed_ms: @elapsed_ms,
          attempts: @attempts,
          backspace_count: @backspace_count,
          reviewed_at: @now
        )
        @card.schedule!(rating: rating, now: @now)
        WordMastery::RecordCoverage.call(review_log: review_log, now: @now) if @correct
        review_log
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
