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
      expect(result).to have_attributes(streak: 0, words_learned: 0, daily_reviews: 0, daily_goal: 50)
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

  describe "#words_learned" do
    it "counts cards with state=REVIEW" do
      create(:card, user: user, state: Card::STATE_REVIEW)
      expect(call.words_learned).to eq(1)
    end

    it "counts cards with mastered_at set" do
      create(:card, user: user, state: Card::STATE_NEW, mastered_at: 1.day.ago)
      expect(call.words_learned).to eq(1)
    end

    it "counts both state=REVIEW and mastered_at cards without double-counting" do
      create(:card, user: user, state: Card::STATE_REVIEW)
      create(:card, user: user, state: Card::STATE_NEW, mastered_at: 1.day.ago)
      expect(call.words_learned).to eq(2)
    end

    it "excludes cards in LEARNING or RELEARNING state" do
      create(:card, user: user, state: Card::STATE_NEW)
      create(:card, user: user, state: Card::STATE_LEARNING)
      create(:card, user: user, state: Card::STATE_RELEARNING)
      expect(call.words_learned).to eq(0)
    end

    it "ignores cards from other users" do
      other_user = create(:user)
      create(:card, user: other_user, state: Card::STATE_REVIEW)
      expect(call.words_learned).to eq(0)
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
