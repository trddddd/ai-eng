module Dashboard
  class BuildProgress
    DAILY_GOAL = 50

    Progress = Struct.new(:streak, :words_learned, :daily_reviews, :daily_goal)

    def self.call(...) = new(...).call

    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def call
      Progress.new(
        streak: ReviewLog.streak_for(@user, now: @now),
        words_learned: Card.where(user: @user).learned.count,
        daily_reviews: ReviewLog.unique_cards_reviewed_on(@user, @now),
        daily_goal: DAILY_GOAL
      )
    end
  end
end
