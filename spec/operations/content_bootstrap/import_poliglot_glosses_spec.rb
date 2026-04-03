require "rails_helper"

RSpec.describe ContentBootstrap::ImportPoliglotGlosses do
  let(:fixture_dir) { Rails.root.join("spec/fixtures/files") }
  let(:english) { Language.find_or_create_by!(code: "en", name: "English") }

  context "with fixture file" do
    before do
      stub_const("ContentBootstrap::ImportPoliglotGlosses::FILE", "poliglot-fixture.json")
      Lexeme.insert_all(
        [
          { language_id: english.id, headword: "apple", created_at: Time.current, updated_at: Time.current },
          { language_id: english.id, headword: "banana", created_at: Time.current, updated_at: Time.current }
        ],
        unique_by: :index_lexemes_on_language_id_and_headword
      )
    end

    it "creates glosses for matched lexemes" do
      # apple: 1, banana: "банан" + "бананы" + "жёлтый фрукт" = 3 → total 4
      expect { described_class.call(data_dir: fixture_dir) }.to change(LexemeGloss, :count).by(4)
    end

    it "creates multiple glosses for word with multiple meanings" do
      described_class.call(data_dir: fixture_dir)

      banana = Lexeme.find_by!(headword: "banana")
      expect(banana.lexeme_glosses.count).to eq(3)
      expect(banana.lexeme_glosses.pluck(:gloss)).to include("банан", "бананы", "жёлтый фрукт")
    end

    it "does not fail when lexeme has no match in poliglot" do
      Lexeme.insert_all(
        [{ language_id: english.id, headword: "zzz_unknown", created_at: Time.current, updated_at: Time.current }],
        unique_by: :index_lexemes_on_language_id_and_headword
      )

      expect { described_class.call(data_dir: fixture_dir) }.not_to raise_error
    end

    it "is idempotent" do
      described_class.call(data_dir: fixture_dir)

      expect { described_class.call(data_dir: fixture_dir) }.not_to change(LexemeGloss, :count)
    end
  end

  context "when file does not exist" do
    before { stub_const("ContentBootstrap::ImportPoliglotGlosses::FILE", "poliglot-translations-missing.json") }

    it "raises with the file name" do
      expect { described_class.call }.to raise_error(RuntimeError, /poliglot-translations/)
    end
  end

  context "when JSON has no 'data' key" do
    let(:bad_dir) do
      dir = Dir.mktmpdir
      File.write(File.join(dir, "poliglot-fixture.json"), '{"wrong": []}')
      Pathname.new(dir)
    end

    before { stub_const("ContentBootstrap::ImportPoliglotGlosses::FILE", "poliglot-fixture.json") }

    it "raises with a descriptive message" do
      expect { described_class.call(data_dir: bad_dir) }.to raise_error(RuntimeError, /missing 'data' key/)
    end
  end
end
