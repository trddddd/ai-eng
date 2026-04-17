require "rails_helper"

RSpec.describe Dashboard::BuildProgress do
  let(:user) { create(:user) }
  let(:now)  { Time.current }

  def call(at: now)
    described_class.call(user: user, now: at)
  end

  def log_for(card, at:)
    create(:review_log, card: card, reviewed_at: at)
  end

  describe "zero state" do
    it "returns zeros when user has no data" do
      result = call
      expect(result).to have_attributes(
        streak: 0,
        daily_reviews: 0,
        daily_goal: 50,
        words_zero_coverage: 0,
        words_partial_coverage: 0,
        words_full_coverage: 0,
        total_words_tracked: 0
      )
    end
  end

  describe "#streak" do
    it "returns 0 when user has never reviewed" do
      expect(call.streak).to eq(0)
    end

    it "returns 0 when last review was not today" do
      card = create(:card, user: user)
      log_for(card, at: 2.days.ago)
      expect(call.streak).to eq(0)
    end

    it "returns 1 when reviewed only today" do
      card = create(:card, user: user)
      log_for(card, at: now)
      expect(call.streak).to eq(1)
    end

    it "counts consecutive days including today" do
      card = create(:card, user: user)
      log_for(card, at: now)
      log_for(card, at: 1.day.ago)
      log_for(card, at: 2.days.ago)
      expect(call.streak).to eq(3)
    end

    it "stops at the first gap" do
      card = create(:card, user: user)
      log_for(card, at: now)
      log_for(card, at: 1.day.ago)
      # gap: no review 2 days ago
      log_for(card, at: 3.days.ago)
      expect(call.streak).to eq(2)
    end

    it "ignores reviews from other users" do
      other_user = create(:user)
      other_card = create(:card, user: other_user)
      log_for(other_card, at: now)
      expect(call.streak).to eq(0)
    end
  end

  describe "word progress buckets (FT-034)" do
    it "counts states with sense_coverage_pct = 0 as zero bucket" do
      create(:user_lexeme_state, user: user, sense_coverage_pct: 0.0)
      create(:user_lexeme_state, user: user, sense_coverage_pct: 0.0)
      result = call
      expect(result.words_zero_coverage).to eq(2)
      expect(result.words_partial_coverage).to eq(0)
      expect(result.words_full_coverage).to eq(0)
      expect(result.total_words_tracked).to eq(2)
    end

    it "counts states with 0 < sense_coverage_pct < 100 as partial bucket" do
      create(:user_lexeme_state, user: user, sense_coverage_pct: 25.0)
      create(:user_lexeme_state, user: user, sense_coverage_pct: 75.5)
      result = call
      expect(result.words_partial_coverage).to eq(2)
      expect(result.words_zero_coverage).to eq(0)
      expect(result.words_full_coverage).to eq(0)
    end

    it "counts states with sense_coverage_pct = 100 as full bucket" do
      create(:user_lexeme_state, user: user, sense_coverage_pct: 100.0)
      result = call
      expect(result.words_full_coverage).to eq(1)
      expect(result.words_zero_coverage).to eq(0)
      expect(result.words_partial_coverage).to eq(0)
    end

    it "returns expected bucket distribution for mixed data" do
      3.times { create(:user_lexeme_state, user: user, sense_coverage_pct: 0.0) }
      5.times { |i| create(:user_lexeme_state, user: user, sense_coverage_pct: 10.0 + i) }
      2.times { create(:user_lexeme_state, user: user, sense_coverage_pct: 100.0) }

      result = call
      expect(result.words_zero_coverage).to eq(3)
      expect(result.words_partial_coverage).to eq(5)
      expect(result.words_full_coverage).to eq(2)
      expect(result.total_words_tracked).to eq(10)
    end

    it "ignores states belonging to other users" do
      other_user = create(:user)
      create(:user_lexeme_state, user: other_user, sense_coverage_pct: 100.0)
      result = call
      expect(result.total_words_tracked).to eq(0)
    end
  end

  describe "#daily_reviews" do
    it "counts unique cards reviewed today" do
      card = create(:card, user: user)
      log_for(card, at: now)
      expect(call.daily_reviews).to eq(1)
    end

    it "counts each card once even with multiple reviews today" do
      card = create(:card, user: user)
      log_for(card, at: now)
      log_for(card, at: now - 1.hour)
      expect(call.daily_reviews).to eq(1)
    end

    it "counts multiple distinct cards reviewed today" do
      card1 = create(:card, user: user)
      card2 = create(:card, user: user)
      log_for(card1, at: now)
      log_for(card2, at: now)
      expect(call.daily_reviews).to eq(2)
    end

    it "excludes reviews from previous days" do
      card = create(:card, user: user)
      log_for(card, at: 1.day.ago)
      expect(call.daily_reviews).to eq(0)
    end

    it "ignores reviews from other users" do
      other_user = create(:user)
      other_card = create(:card, user: other_user)
      log_for(other_card, at: now)
      expect(call.daily_reviews).to eq(0)
    end
  end

  describe "#daily_goal" do
    it "always returns the DAILY_GOAL constant" do
      expect(call.daily_goal).to eq(Dashboard::BuildProgress::DAILY_GOAL)
    end
  end
end
