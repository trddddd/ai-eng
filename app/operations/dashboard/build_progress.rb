module Dashboard
  class BuildProgress
    DAILY_GOAL = 50

    Progress = Struct.new(
      :streak,
      :daily_reviews,
      :daily_goal,
      :words_zero_coverage,
      :words_partial_coverage,
      :words_full_coverage
    ) do
      def total_words_tracked = words_zero_coverage + words_partial_coverage + words_full_coverage
    end

    def self.call(...) = new(...).call

    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def call
      buckets = word_buckets

      Progress.new(
        streak: ReviewLog.streak_for(@user, now: @now),
        daily_reviews: ReviewLog.unique_cards_reviewed_on(@user, @now),
        daily_goal: DAILY_GOAL,
        words_zero_coverage: buckets.fetch(:zero, 0),
        words_partial_coverage: buckets.fetch(:partial, 0),
        words_full_coverage: buckets.fetch(:full, 0)
      )
    end

    private

    def word_buckets
      UserLexemeState.where(user: @user).pluck(:sense_coverage_pct).each_with_object(Hash.new(0)) do |pct, acc|
        acc[bucket_for(pct)] += 1
      end
    end

    def bucket_for(pct)
      return :zero if pct.zero?
      return :full if pct >= 100.0

      :partial
    end
  end
end
