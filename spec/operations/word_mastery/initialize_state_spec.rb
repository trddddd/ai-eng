require "rails_helper"

RSpec.describe WordMastery::InitializeState, type: :operation do
  let(:user) { create(:user) }
  let(:lexeme) { create(:lexeme) }

  describe ".call" do
    it "creates a new UserLexemeState" do
      expect { described_class.call(user: user, lexeme: lexeme) }
        .to change(UserLexemeState, :count).by(1)
    end

    it "sets total_sense_count from lexeme senses" do
      create_list(:sense, 3, lexeme: lexeme)
      state = described_class.call(user: user, lexeme: lexeme)
      expect(state.total_sense_count).to eq(3)
    end

    it "sets total_family_count from unique sentence_occurrence families" do
      family = create(:context_family)
      create(:sentence_occurrence, lexeme: lexeme, context_family: family)
      state = described_class.call(user: user, lexeme: lexeme)
      expect(state.total_family_count).to eq(1)
    end

    it "is idempotent — returns existing state without creating duplicate" do
      first = described_class.call(user: user, lexeme: lexeme)
      expect { described_class.call(user: user, lexeme: lexeme) }
        .not_to change(UserLexemeState, :count)
      second = described_class.call(user: user, lexeme: lexeme)
      expect(second.id).to eq(first.id)
    end

    it "defaults coverage counters to zero" do
      state = described_class.call(user: user, lexeme: lexeme)
      expect(state.covered_sense_count).to eq(0)
      expect(state.sense_coverage_pct).to eq(0.0)
      expect(state.covered_family_count).to eq(0)
      expect(state.family_coverage_pct).to eq(0.0)
      expect(state.last_covered_at).to be_nil
    end
  end
end
