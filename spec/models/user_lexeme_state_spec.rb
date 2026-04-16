require "rails_helper"

RSpec.describe UserLexemeState, type: :model do
  let(:state) { build(:user_lexeme_state) }

  it "has a valid factory" do
    expect(state).to be_valid
  end

  describe "validations" do
    it "requires unique user_id scoped to lexeme_id" do
      existing = create(:user_lexeme_state)
      duplicate = build(:user_lexeme_state, user: existing.user, lexeme: existing.lexeme)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("уже существует")
    end

    it "allows same user with different lexemes" do
      user = create(:user)
      create(:user_lexeme_state, user: user)
      other = build(:user_lexeme_state, user: user)
      expect(other).to be_valid
    end

    it "rejects negative covered_sense_count" do
      state.covered_sense_count = -1
      expect(state).not_to be_valid
    end

    it "rejects negative total_sense_count" do
      state.total_sense_count = -1
      expect(state).not_to be_valid
    end

    it "rejects sense_coverage_pct outside 0..100" do
      state.sense_coverage_pct = -0.1
      expect(state).not_to be_valid

      state.sense_coverage_pct = 100.1
      expect(state).not_to be_valid
    end

    it "accepts sense_coverage_pct boundary values" do
      state.sense_coverage_pct = 0.0
      expect(state).to be_valid

      state.sense_coverage_pct = 100.0
      expect(state).to be_valid
    end

    it "rejects negative covered_family_count" do
      state.covered_family_count = -1
      expect(state).not_to be_valid
    end

    it "rejects family_coverage_pct outside 0..100" do
      state.family_coverage_pct = -0.1
      expect(state).not_to be_valid

      state.family_coverage_pct = 100.1
      expect(state).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to user" do
      expect(state.user).to be_present
    end

    it "belongs to lexeme" do
      expect(state.lexeme).to be_present
    end

    it "has many user_sense_coverages" do
      expect(described_class.reflect_on_association(:user_sense_coverages).macro).to eq(:has_many)
    end

    it "has many user_context_family_coverages" do
      expect(described_class.reflect_on_association(:user_context_family_coverages).macro).to eq(:has_many)
    end
  end

  describe "defaults" do
    it "defaults counters to zero" do
      record = described_class.new
      expect(record.covered_sense_count).to eq(0)
      expect(record.total_sense_count).to eq(0)
      expect(record.covered_family_count).to eq(0)
      expect(record.total_family_count).to eq(0)
    end

    it "defaults percentages to zero" do
      record = described_class.new
      expect(record.sense_coverage_pct).to eq(0.0)
      expect(record.family_coverage_pct).to eq(0.0)
    end

    it "defaults last_covered_at to nil" do
      record = described_class.new
      expect(record.last_covered_at).to be_nil
    end
  end
end
