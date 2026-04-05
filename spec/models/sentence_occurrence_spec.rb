require "rails_helper"

RSpec.describe SentenceOccurrence, type: :model do
  let(:sentence_occurrence) { build(:sentence_occurrence) }

  describe "validations" do
    it { expect(sentence_occurrence).to be_valid }

    it "requires form" do
      sentence_occurrence.form = nil
      expect(sentence_occurrence).not_to be_valid
    end

    it "requires sentence" do
      sentence_occurrence.sentence = nil
      expect(sentence_occurrence).not_to be_valid
    end

    it "requires lexeme" do
      sentence_occurrence.lexeme = nil
      expect(sentence_occurrence).not_to be_valid
    end

    it "requires unique (sentence_id, lexeme_id)" do
      sentence = create(:sentence)
      lexeme = create(:lexeme)
      create(:sentence_occurrence, sentence: sentence, lexeme: lexeme)
      duplicate = build(:sentence_occurrence, sentence: sentence, lexeme: lexeme)
      expect(duplicate).not_to be_valid
    end
  end

  describe "#cloze_text" do
    it "replaces the first occurrence of form with ____" do
      sentence = build(:sentence, text: "Run and run")
      occurrence = build(:sentence_occurrence, sentence: sentence, form: "run")
      expect(occurrence.cloze_text).to eq("Run and ____")
    end

    it "replaces only the first occurrence when form appears multiple times" do
      sentence = build(:sentence, text: "run and run again")
      occurrence = build(:sentence_occurrence, sentence: sentence, form: "run")
      expect(occurrence.cloze_text).to eq("____ and run again")
    end
  end
end
