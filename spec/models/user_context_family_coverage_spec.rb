require "rails_helper"

RSpec.describe UserContextFamilyCoverage, type: :model do
  let(:coverage) { build(:user_context_family_coverage) }

  it "has a valid factory" do
    expect(coverage).to be_valid
  end

  describe "validations" do
    it "requires unique user_id scoped to lexeme_id and context_family_id" do
      existing = create(:user_context_family_coverage)
      duplicate = build(:user_context_family_coverage,
                        user: existing.user,
                        lexeme: existing.lexeme,
                        context_family: existing.context_family)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("уже существует")
    end

    it "allows same user and lexeme with different context_families" do
      user = create(:user)
      lexeme = create(:lexeme)
      create(:user_context_family_coverage, user: user, lexeme: lexeme)
      other = build(:user_context_family_coverage, user: user, lexeme: lexeme)
      expect(other).to be_valid
    end

    it "requires first_correct_at" do
      coverage.first_correct_at = nil
      expect(coverage).not_to be_valid
      expect(coverage.errors[:first_correct_at]).to include("не может быть пустым")
    end
  end

  describe "associations" do
    it "belongs to user" do
      expect(coverage.user).to be_present
    end

    it "belongs to lexeme" do
      expect(coverage.lexeme).to be_present
    end

    it "belongs to context_family" do
      expect(coverage.context_family).to be_present
    end
  end
end
