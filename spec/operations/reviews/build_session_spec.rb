require "rails_helper"

RSpec.describe Reviews::BuildSession do
  let(:user) { create(:user) }

  describe ".call" do
    context "with card debt only" do
      it "returns due cards sorted by due ASC" do
        older = create(:card, user: user, due: 2.hours.ago)
        newer = create(:card, user: user, due: 30.minutes.ago)
        result = described_class.call(user: user)
        expect(result).to eq([older, newer])
      end

      it "excludes future cards" do
        create(:card, user: user, due: 1.hour.from_now)
        expect(described_class.call(user: user)).to be_empty
      end

      it "excludes mastered cards" do
        create(:card, user: user, due: 1.hour.ago, mastered_at: Time.current)
        expect(described_class.call(user: user)).to be_empty
      end

      it "limits to BATCH_SIZE" do
        11.times { create(:card, user: user, due: 1.hour.ago) }
        expect(described_class.call(user: user).count).to eq(10)
      end

      it "returns empty when no due cards" do
        expect(described_class.call(user: user)).to be_empty
      end

      # SC-01: card debt fills limit → no word debt
      it "does not add word debt when card debt fills the limit" do
        lexeme = create(:lexeme)
        create(:user_lexeme_state, user: user, lexeme: lexeme, family_coverage_pct: 50.0)
        occ = create(:sentence_occurrence, lexeme: lexeme)

        10.times { create(:card, user: user, due: 1.hour.ago) }

        result = described_class.call(user: user, limit: 10)

        expect(result.size).to eq(10)
        expect(Card.where(sentence_occurrence: occ)).to be_empty
      end
    end

    context "with word debt candidates" do
      let(:lexeme) { create(:lexeme) }
      let(:family_a) { create(:context_family) }
      let(:family_b) { create(:context_family) }
      let(:family_c) { create(:context_family) }

      # SC-02: mixed session — card debt + word debt
      it "fills remaining slots with word debt cards" do
        3.times { create(:card, user: user, due: 1.hour.ago) }

        lexeme1 = create(:lexeme)
        lexeme2 = create(:lexeme)
        create(:user_lexeme_state, user: user, lexeme: lexeme1,
                                   family_coverage_pct: 50.0, total_family_count: 2, covered_family_count: 1)
        create(:user_lexeme_state, user: user, lexeme: lexeme2,
                                   family_coverage_pct: 50.0, total_family_count: 2, covered_family_count: 1)

        create(:sentence_occurrence, lexeme: lexeme1, context_family: family_a)
        create(:sentence_occurrence, lexeme: lexeme2, context_family: family_b)

        result = described_class.call(user: user, limit: 10)

        expect(result.size).to eq(5)
        word_debt_cards = result.last(2)
        expect(word_debt_cards).to all(have_attributes(state: Card::STATE_NEW))
      end

      # SC-03: unseen family preference
      it "prefers occurrence from uncovered context family" do
        create(:user_lexeme_state, user: user, lexeme: lexeme,
                                   family_coverage_pct: 33.3, total_family_count: 3, covered_family_count: 1)

        create(:sentence_occurrence, lexeme: lexeme, context_family: family_a)
        uncovered_occ_b = create(:sentence_occurrence, lexeme: lexeme, context_family: family_b)

        create(:user_context_family_coverage,
               user: user, lexeme: lexeme, context_family: family_a)

        result = described_class.call(user: user, limit: 10)

        expect(result.size).to eq(1)
        expect(result.first.sentence_occurrence).to eq(uncovered_occ_b)
      end

      # SC-05: sense fallback when all families covered
      it "falls back to uncovered sense when all families are covered" do
        sense_a = create(:sense, lexeme: lexeme)
        sense_b = create(:sense, lexeme: lexeme)

        create(:user_lexeme_state, user: user, lexeme: lexeme,
                                   family_coverage_pct: 50.0, total_family_count: 2, covered_family_count: 1,
                                   sense_coverage_pct: 50.0, total_sense_count: 2, covered_sense_count: 1)

        create(:sentence_occurrence, lexeme: lexeme,
                                     context_family: family_a, sense: sense_a)
        uncovered_sense_occ = create(:sentence_occurrence, lexeme: lexeme,
                                                           context_family: family_b, sense: sense_b)

        # Cover both families
        create(:user_context_family_coverage,
               user: user, lexeme: lexeme, context_family: family_a)
        create(:user_context_family_coverage,
               user: user, lexeme: lexeme, context_family: family_b)

        # Cover only sense_a
        create(:user_sense_coverage, user: user, sense: sense_a)

        # User already has card for sense_a occurrence
        create(:card, user: user,
                      sentence_occurrence: SentenceOccurrence.find_by(sense: sense_a),
                      due: 1.day.from_now)

        result = described_class.call(user: user, limit: 10)

        expect(result.size).to eq(1)
        expect(result.first.sentence_occurrence).to eq(uncovered_sense_occ)
      end

      # SC-04: no word debt candidates
      it "returns only card debt when all lexemes fully covered" do
        due_card = create(:card, user: user, due: 1.hour.ago)
        create(:user_lexeme_state, user: user, lexeme: lexeme,
                                   family_coverage_pct: 100.0, total_family_count: 2, covered_family_count: 2)

        result = described_class.call(user: user, limit: 10)

        expect(result).to eq([due_card])
      end

      # REQ-06: word debt ranking — lowest coverage first
      it "prioritizes lexemes with lowest family_coverage_pct" do
        lexeme_low = create(:lexeme)
        lexeme_high = create(:lexeme)

        create(:user_lexeme_state, user: user, lexeme: lexeme_low,
                                   family_coverage_pct: 25.0, total_family_count: 4, covered_family_count: 1)
        create(:user_lexeme_state, user: user, lexeme: lexeme_high,
                                   family_coverage_pct: 75.0, total_family_count: 4, covered_family_count: 3)

        occ_low = create(:sentence_occurrence, lexeme: lexeme_low, context_family: family_a)
        create(:sentence_occurrence, lexeme: lexeme_high, context_family: family_b)

        result = described_class.call(user: user, limit: 1)

        expect(result.size).to eq(1)
        expect(result.first.sentence_occurrence).to eq(occ_low)
      end

      # EC-04: word debt card has correct FSRS defaults
      it "creates word debt card with STATE_NEW and due: now" do
        now = Time.current
        create(:user_lexeme_state, user: user, lexeme: lexeme,
                                   family_coverage_pct: 50.0, total_family_count: 2, covered_family_count: 1)
        create(:sentence_occurrence, lexeme: lexeme, context_family: family_a)

        result = described_class.call(user: user, limit: 10, now: now)

        card = result.first
        expect(card.state).to eq(Card::STATE_NEW)
        expect(card.due).to be_within(1.second).of(now)
        expect(card.stability).to eq(0.0)
        expect(card.difficulty).to eq(0.0)
      end

      # ASM-05 / NEG-06: one word debt card per lexeme
      it "creates at most one word debt card per lexeme" do
        create(:user_lexeme_state, user: user, lexeme: lexeme,
                                   family_coverage_pct: 33.3, total_family_count: 3, covered_family_count: 1)

        create(:sentence_occurrence, lexeme: lexeme, context_family: family_a)
        create(:sentence_occurrence, lexeme: lexeme, context_family: family_b)
        create(:sentence_occurrence, lexeme: lexeme, context_family: family_c)

        result = described_class.call(user: user, limit: 10)

        word_debt_cards = result.select { |c| c.sentence_occurrence.lexeme == lexeme }
        expect(word_debt_cards.size).to eq(1)
      end
    end

    context "with edge cases" do
      # NEG-01: new user without UserLexemeState
      it "returns only card debt for user without lexeme states" do
        Array.new(3) { create(:card, user: user, due: 1.hour.ago) }

        result = described_class.call(user: user, limit: 10)

        expect(result.size).to eq(3)
      end

      # NEG-02: lexeme with only existing-card occurrences
      it "skips lexeme when all occurrences already have cards" do
        lexeme = create(:lexeme)
        occ = create(:sentence_occurrence, lexeme: lexeme, context_family: create(:context_family))
        create(:card, user: user, sentence_occurrence: occ, due: 1.day.from_now)

        create(:user_lexeme_state, user: user, lexeme: lexeme,
                                   family_coverage_pct: 50.0, total_family_count: 2, covered_family_count: 1)

        result = described_class.call(user: user, limit: 10)

        expect(result).to be_empty
      end

      # NEG-03: all occurrences have NULL context_family_id and NULL sense_id
      it "skips lexeme when all occurrences have NULL context_family and sense" do
        lexeme = create(:lexeme)
        sentence = create(:sentence)
        # Bypass factory after(:build) callback that auto-creates sense
        SentenceOccurrence.create!(
          sentence: sentence, lexeme: lexeme, form: "word",
          context_family_id: nil, sense_id: nil
        )

        create(:user_lexeme_state, user: user, lexeme: lexeme,
                                   family_coverage_pct: 50.0, total_family_count: 2, covered_family_count: 1)

        result = described_class.call(user: user, limit: 10)

        expect(result).to be_empty
      end

      # NEG-04: unique constraint violation (race condition)
      it "skips occurrence on unique constraint violation" do
        lexeme = create(:lexeme)
        family = create(:context_family)
        occ = create(:sentence_occurrence, lexeme: lexeme, context_family: family)

        create(:user_lexeme_state, user: user, lexeme: lexeme,
                                   family_coverage_pct: 50.0, total_family_count: 2, covered_family_count: 1)

        # Pre-create the card to simulate race condition
        create(:card, user: user, sentence_occurrence: occ, due: 1.day.from_now)

        expect { described_class.call(user: user, limit: 10) }.not_to raise_error
      end

      # NEG-05: remaining_slots = 0
      it "does not run word debt when card debt fills limit" do
        10.times { create(:card, user: user, due: 1.hour.ago) }
        lexeme = create(:lexeme)
        create(:user_lexeme_state, user: user, lexeme: lexeme, family_coverage_pct: 50.0)

        expect do
          described_class.call(user: user, limit: 10)
        end.not_to change(Card, :count)
      end

      # NEG-07: limit 0
      it "returns empty array with no side effects when limit is 0" do
        lexeme = create(:lexeme)
        create(:user_lexeme_state, user: user, lexeme: lexeme, family_coverage_pct: 50.0)
        create(:sentence_occurrence, lexeme: lexeme, context_family: create(:context_family))

        result = nil
        expect do
          result = described_class.call(user: user, limit: 0)
        end.not_to change(Card, :count)

        expect(result).to be_empty
      end

      # FM-01: no word debt candidates
      it "returns empty when no due cards and no word debt candidates" do
        result = described_class.call(user: user, limit: 10)
        expect(result).to be_empty
      end
    end
  end
end
