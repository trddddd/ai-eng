require "rails_helper"

RSpec.describe LexemeGloss, type: :model do
  subject(:lexeme_gloss) { build(:lexeme_gloss) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires gloss" do
      lexeme_gloss.gloss = nil
      expect(lexeme_gloss).not_to be_valid
    end

    it "requires lexeme" do
      lexeme_gloss.lexeme = nil
      expect(lexeme_gloss).not_to be_valid
    end

    it "requires target_language" do
      lexeme_gloss.target_language = nil
      expect(lexeme_gloss).not_to be_valid
    end

    it "requires unique gloss per lexeme and target_language" do
      lexeme = create(:lexeme)
      target_language = create(:language)
      create(:lexeme_gloss, lexeme: lexeme, target_language: target_language, gloss: "hello")
      lexeme_gloss.lexeme = lexeme
      lexeme_gloss.target_language = target_language
      lexeme_gloss.gloss = "hello"
      expect(lexeme_gloss).not_to be_valid
    end
  end
end
