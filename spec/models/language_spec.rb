require "rails_helper"

RSpec.describe Language, type: :model do
  subject(:language) { build(:language) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires code" do
      language.code = nil
      expect(language).not_to be_valid
    end

    it "requires name" do
      language.name = nil
      expect(language).not_to be_valid
    end

    it "requires unique code" do
      create(:language, code: "ru")
      language.code = "ru"
      expect(language).not_to be_valid
    end
  end
end
