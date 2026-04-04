require "rails_helper"

RSpec.describe Lexeme, type: :model do
  subject(:lexeme) { build(:lexeme) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires headword" do
      lexeme.headword = nil
      expect(lexeme).not_to be_valid
    end

    it "requires language" do
      lexeme.language = nil
      expect(lexeme).not_to be_valid
    end

    it "requires unique headword within language" do
      language = create(:language)
      create(:lexeme, language: language, headword: "test")
      lexeme.language = language
      lexeme.headword = "test"
      expect(lexeme).not_to be_valid
    end
  end
end
