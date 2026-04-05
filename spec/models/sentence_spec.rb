require "rails_helper"

RSpec.describe Sentence, type: :model do
  let(:sentence) { build(:sentence) }

  describe "validations" do
    it { expect(sentence).to be_valid }

    it "requires text" do
      sentence.text = nil
      expect(sentence).not_to be_valid
    end

    it "requires source" do
      sentence.source = nil
      expect(sentence).not_to be_valid
    end

    it "requires language" do
      sentence.language = nil
      expect(sentence).not_to be_valid
    end

    it "requires unique text within language" do
      language = create(:language)
      create(:sentence, language: language, text: "Hello world")
      sentence.language = language
      sentence.text = "Hello world"
      expect(sentence).not_to be_valid
    end

    it "rejects text containing ____" do
      sentence.text = "She is ____ fast."
      expect(sentence).not_to be_valid
    end

    it "accepts text without ____" do
      sentence.text = "She is running fast."
      expect(sentence).to be_valid
    end
  end
end
