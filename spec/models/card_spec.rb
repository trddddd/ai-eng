require "rails_helper"

RSpec.describe Card, type: :model do
  let(:card) { build(:card) }

  describe "validations" do
    it { expect(card).to be_valid }

    it "requires due" do
      card.due = nil
      expect(card).not_to be_valid
    end

    it "requires user" do
      card.user = nil
      expect(card).not_to be_valid
    end

    it "requires sentence_occurrence" do
      card.sentence_occurrence = nil
      expect(card).not_to be_valid
    end

    it "rejects invalid state" do
      card.state = 99
      expect(card).not_to be_valid
    end

    it "accepts all valid states" do
      [Card::STATE_NEW, Card::STATE_LEARNING, Card::STATE_REVIEW, Card::STATE_RELEARNING].each do |s|
        card.state = s
        expect(card).to be_valid
      end
    end

    it "enforces uniqueness of sentence_occurrence per user" do
      existing = create(:card)
      duplicate = build(:card, user: existing.user, sentence_occurrence: existing.sentence_occurrence)
      expect(duplicate).not_to be_valid
    end
  end

  describe "#to_fsrs_card" do
    # rubocop:disable RSpec/ExampleLength
    it "returns an Fsrs::Card with matching attributes" do
      freeze_time do
        card.due = Time.current
        card.stability = 1.5
        card.difficulty = 3.2
        card.elapsed_days = 2
        card.scheduled_days = 5
        card.reps = 3
        card.lapses = 1
        card.state = Card::STATE_REVIEW
        card.last_review = 1.day.ago

        fsrs_card = card.to_fsrs_card

        expect(fsrs_card).to have_attributes(
          due: card.due,
          stability: card.stability,
          difficulty: card.difficulty,
          elapsed_days: card.elapsed_days,
          scheduled_days: card.scheduled_days,
          reps: card.reps,
          lapses: card.lapses,
          state: card.state,
          last_review: card.last_review
        )
      end
    end
    # rubocop:enable RSpec/ExampleLength
  end

  describe ".due_for_review" do
    let(:user) { create(:user) }

    it "returns cards with due <= now" do
      card = create(:card, user: user, due: 1.hour.ago)
      expect(described_class.due_for_review(user)).to include(card)
    end

    it "excludes cards with due in the future" do
      create(:card, user: user, due: 1.hour.from_now)
      expect(described_class.due_for_review(user)).to be_empty
    end

    it "excludes mastered cards" do
      create(:card, user: user, due: 1.hour.ago, mastered_at: Time.current)
      expect(described_class.due_for_review(user)).to be_empty
    end

    it "excludes cards from other users" do
      other_user = create(:user)
      create(:card, user: other_user, due: 1.hour.ago)
      expect(described_class.due_for_review(user)).to be_empty
    end
  end

  describe "#schedule!" do
    it "updates FSRS fields after scheduling" do
      persisted_card = create(:card)
      original_due = persisted_card.due
      persisted_card.schedule!(rating: ReviewLog::RATING_GOOD)
      persisted_card.reload

      expect(persisted_card.reps).to eq(1)
      expect(persisted_card.due).not_to eq(original_due)
    end
  end

  describe "#master!" do
    it "sets mastered_at" do
      persisted_card = create(:card)
      expect { persisted_card.master! }.to change { persisted_card.reload.mastered_at }.from(nil)
    end
  end

  describe "#mastered?" do
    it "returns false when mastered_at is nil" do
      expect(build(:card, mastered_at: nil)).not_to be_mastered
    end

    it "returns true when mastered_at is set" do
      expect(build(:card, mastered_at: Time.current)).to be_mastered
    end
  end

  describe "#apply_fsrs_card!" do
    # rubocop:disable RSpec/ExampleLength
    it "persists FSRS state from an Fsrs::Card" do
      freeze_time do
        card.save!
        fsrs_card = Fsrs::Card.new
        fsrs_card.due = 3.days.from_now
        fsrs_card.stability = 2.5
        fsrs_card.difficulty = 4.1
        fsrs_card.elapsed_days = 3
        fsrs_card.scheduled_days = 7
        fsrs_card.reps = 5
        fsrs_card.lapses = 0
        fsrs_card.state = Card::STATE_REVIEW
        fsrs_card.last_review = Time.current

        card.apply_fsrs_card!(fsrs_card)

        expect(card.reload).to have_attributes(
          due: fsrs_card.due,
          stability: fsrs_card.stability,
          difficulty: fsrs_card.difficulty,
          elapsed_days: fsrs_card.elapsed_days,
          scheduled_days: fsrs_card.scheduled_days,
          reps: fsrs_card.reps,
          lapses: fsrs_card.lapses,
          state: fsrs_card.state,
          last_review: fsrs_card.last_review
        )
      end
    end
    # rubocop:enable RSpec/ExampleLength
  end
end
