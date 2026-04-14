require "rails_helper"

RSpec.describe Sentences::ImportTatoeba, type: :operation do
  describe ".call" do
    let!(:english) { create(:language, code: "en", name: "English") }
    let(:data_dir) { Rails.root.join("db/data/tatoeba") }

    # TSV content: id TAB lang TAB text
    let(:sentences_tsv) do
      "1\teng\tHello world.\n2\teng\tThis is a test sentence.\n3\teng\tAnother example.\n4\trus\tПривет мир.\n5\trus\tЭто тестовое предложение.\n"
    end

    # TSV content: eng_id TAB rus_id
    let(:links_tsv) do
      "1\t4\n2\t5\n"
    end

    before do
      FileUtils.mkdir_p(data_dir)
      File.write(data_dir.join("sentences.csv"), sentences_tsv)
      File.write(data_dir.join("links.csv"), links_tsv)
    end

    after do
      FileUtils.rm_rf(data_dir)
    end

    context "with valid Tatoeba data files" do
      before do
        create(:lexeme, headword: "hello", language: english)
        create(:lexeme, headword: "test", language: english)
      end

      it "imports only English sentences that have Russian translations" do
        expect { described_class.call }.to change(Sentence, :count).by(2)
      end

      it "sets source to 'tatoeba'" do
        described_class.call
        expect(Sentence.where(source: "tatoeba").count).to eq(2)
      end

      it "stores tatoeba_id for imported sentences" do
        described_class.call
        expect(Sentence.find_by(tatoeba_id: 1)).to be_present
        expect(Sentence.find_by(tatoeba_id: 2)).to be_present
        expect(Sentence.find_by(tatoeba_id: 3)).to be_nil # no Russian translation
      end

      it "skips English sentences without Russian translations" do
        described_class.call
        expect(Sentence.count).to eq(2)
      end

      it "imports Russian translations for linked English sentences" do
        described_class.call
        hello_sentence = Sentence.find_by(tatoeba_id: 1)
        expect(hello_sentence.sentence_translations.count).to eq(1)
        expect(hello_sentence.sentence_translations.first.text).to eq("Привет мир.")
      end

      it "creates sentence occurrences for matched lexemes" do
        # sentence 1 matches "hello", sentence 2 matches "test" (both have Russian translations)
        expect { described_class.call }.to change(SentenceOccurrence, :count).by(2)
      end

      it "sets correct form on occurrence" do
        described_class.call
        occurrence = SentenceOccurrence.joins(:lexeme).find_by(lexemes: { headword: "hello" })
        expect(occurrence.form).to eq("Hello")
      end

      it "is idempotent - does not duplicate sentences on second run" do
        described_class.call
        expect { described_class.call }.not_to(change(Sentence, :count))
      end

      it "is idempotent - does not duplicate occurrences on second run" do
        described_class.call
        expect { described_class.call }.not_to(change(SentenceOccurrence, :count))
      end
    end

    context "without existing lexemes" do
      it "raises an error" do
        expect { described_class.call }.to raise_error(/No lexemes in DB/)
      end
    end

    context "when Tatoeba files do not exist" do
      before { FileUtils.rm_rf(data_dir) }

      it "does not raise an error" do
        create(:lexeme, headword: "hello", language: english)
        expect { described_class.call }.not_to raise_error
      end
    end

    context "with existing quizword sentences" do
      before do
        create(:sentence, text: "Hello world.", language: english, source: "quizword")
        create(:lexeme, headword: "hello", language: english)
      end

      it "does not duplicate existing sentences" do
        described_class.call
        expect(Sentence.where(text: "Hello world.").count).to eq(1)
      end

      it "creates new Tatoeba sentences not already in DB" do
        # sentence 1 ("Hello world.") exists as quizword, sentence 2 is new; sentence 3 skipped (no Russian link)
        expect { described_class.call }.to change(Sentence, :count).by(1)
      end

      it "leaves quizword source unchanged" do
        described_class.call
        expect(Sentence.find_by(text: "Hello world.").source).to eq("quizword")
      end
    end
  end
end
