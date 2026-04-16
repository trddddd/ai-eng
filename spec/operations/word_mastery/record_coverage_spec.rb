require "rails_helper"

RSpec.describe WordMastery::RecordCoverage, type: :operation do
  let(:user) { create(:user) }
  let(:lexeme) { create(:lexeme) }

  describe ".call with correct answer" do
    it "creates coverage records" do
      sense = create(:sense, lexeme: lexeme)
      family = create(:context_family)
      occurrence = create(:sentence_occurrence, lexeme: lexeme, sense: sense, context_family: family)
      card = create(:card, user: user, sentence_occurrence: occurrence)
      review_log = create(:review_log, card: card, correct: true)

      expect { described_class.call(review_log: review_log) }
        .to change(UserSenseCoverage, :count).by(1)
        .and change(UserContextFamilyCoverage, :count).by(1)
        .and change(UserLexemeState, :count).by(1)
    end

    it "updates state with correct counters and percentages" do
      sense = create(:sense, lexeme: lexeme)
      family = create(:context_family)
      occurrence = create(:sentence_occurrence, lexeme: lexeme, sense: sense, context_family: family)
      card = create(:card, user: user, sentence_occurrence: occurrence)
      review_log = create(:review_log, card: card, correct: true)

      described_class.call(review_log: review_log)
      state = UserLexemeState.find_by(user: user, lexeme: lexeme)

      expect(state.covered_sense_count).to eq(1)
      expect(state.covered_family_count).to eq(1)
      expect(state.sense_coverage_pct).to eq(100.0)
      expect(state.family_coverage_pct).to eq(100.0)
      expect(state.last_covered_at).to be_within(1.second).of(Time.current)
    end
  end

  describe ".call with incorrect answer" do
    it "does not create any records" do
      sense = create(:sense, lexeme: lexeme)
      occurrence = create(:sentence_occurrence, lexeme: lexeme, sense: sense)
      card = create(:card, user: user, sentence_occurrence: occurrence)
      review_log = create(:review_log, card: card, correct: false)

      expect { described_class.call(review_log: review_log) }
        .not_to change(UserSenseCoverage, :count)
      expect { described_class.call(review_log: review_log) }
        .not_to change(UserLexemeState, :count)
    end
  end

  describe "idempotency" do
    it "does not duplicate coverage on repeated call" do
      sense = create(:sense, lexeme: lexeme)
      occurrence = create(:sentence_occurrence, lexeme: lexeme, sense: sense)
      card = create(:card, user: user, sentence_occurrence: occurrence)
      review_log = create(:review_log, card: card, correct: true)

      described_class.call(review_log: review_log)
      expect { described_class.call(review_log: review_log) }
        .not_to change(UserSenseCoverage, :count)
      expect { described_class.call(review_log: review_log) }
        .not_to change(UserContextFamilyCoverage, :count)

      state = UserLexemeState.find_by(user: user, lexeme: lexeme)
      expect { described_class.call(review_log: review_log) }
        .not_to(change { state.reload.covered_sense_count })
    end
  end

  describe "multiple senses coverage" do
    it "tracks coverage across different senses" do
      sense1 = create(:sense, lexeme: lexeme)
      sense2 = create(:sense, lexeme: lexeme)
      family1 = create(:context_family)
      family2 = create(:context_family)
      occ1 = create(:sentence_occurrence, lexeme: lexeme, sense: sense1, context_family: family1)
      occ2 = create(:sentence_occurrence, lexeme: lexeme, sense: sense2, context_family: family2)
      card1 = create(:card, user: user, sentence_occurrence: occ1)
      card2 = create(:card, user: user, sentence_occurrence: occ2)

      described_class.call(review_log: create(:review_log, card: card1, correct: true))
      described_class.call(review_log: create(:review_log, card: card2, correct: true))

      state = UserLexemeState.find_by(user: user, lexeme: lexeme)
      expect(state.covered_sense_count).to eq(2)
      expect(state.total_sense_count).to eq(2)
      expect(state.sense_coverage_pct).to eq(100.0)
      expect(state.covered_family_count).to eq(2)
    end
  end

  describe "NULL sense edge case (FM-01)" do
    it "creates state and family coverage but skips sense coverage" do
      family = create(:context_family)
      occurrence = create(:sentence_occurrence, lexeme: lexeme, context_family: family)
      occurrence.update_column(:sense_id, nil)
      card = create(:card, user: user, sentence_occurrence: occurrence)
      review_log = create(:review_log, card: card, correct: true)

      expect { described_class.call(review_log: review_log) }
        .to change(UserLexemeState, :count).by(1)
      expect { described_class.call(review_log: review_log) }
        .not_to change(UserSenseCoverage, :count)
      expect { described_class.call(review_log: review_log) }
        .not_to change(UserContextFamilyCoverage, :count) # already created in first call
    end
  end
end
