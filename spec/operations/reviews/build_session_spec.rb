require "rails_helper"

RSpec.describe Reviews::BuildSession do
  let(:user) { create(:user) }

  describe ".call" do
    it "returns due cards sorted by due ASC" do
      older = create(:card, user: user, due: 2.hours.ago)
      newer = create(:card, user: user, due: 30.minutes.ago)
      result = described_class.call(user: user)
      expect(result.to_a).to eq([older, newer])
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
  end
end
