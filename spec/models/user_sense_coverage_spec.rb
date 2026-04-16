require "rails_helper"

RSpec.describe UserSenseCoverage, type: :model do
  let(:coverage) { build(:user_sense_coverage) }

  it "has a valid factory" do
    expect(coverage).to be_valid
  end

  describe "validations" do
    it "requires unique user_id scoped to sense_id" do
      existing = create(:user_sense_coverage)
      duplicate = build(:user_sense_coverage, user: existing.user, sense: existing.sense)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("уже существует")
    end

    it "allows same user with different senses" do
      user = create(:user)
      create(:user_sense_coverage, user: user)
      other = build(:user_sense_coverage, user: user)
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

    it "belongs to sense" do
      expect(coverage.sense).to be_present
    end
  end
end
