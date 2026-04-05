require "rails_helper"

RSpec.describe SentenceTranslation, type: :model do
  let(:sentence_translation) { build(:sentence_translation) }

  describe "validations" do
    it { expect(sentence_translation).to be_valid }

    it "requires text" do
      sentence_translation.text = nil
      expect(sentence_translation).not_to be_valid
    end

    it "requires sentence" do
      sentence_translation.sentence = nil
      expect(sentence_translation).not_to be_valid
    end

    it "requires target_language" do
      sentence_translation.target_language = nil
      expect(sentence_translation).not_to be_valid
    end

    it "requires unique (sentence_id, target_language_id)" do
      language = create(:language)
      sentence = create(:sentence)
      create(:sentence_translation, sentence: sentence, target_language: language)
      duplicate = build(:sentence_translation, sentence: sentence, target_language: language)
      expect(duplicate).not_to be_valid
    end
  end
end
