require "rails_helper"

RSpec.describe ContentBootstrap::ImportOxfordLexemes do
  let(:fixture_dir) { Rails.root.join("spec/fixtures/files") }

  context "with fixture file" do
    before { stub_const("ContentBootstrap::ImportOxfordLexemes::FILE", "oxford-5000-fixture.csv") }

    it "imports valid lexemes with pos and cefr_level" do
      expect { described_class.call(data_dir: fixture_dir) }.to change(Lexeme, :count).by(2)

      apple = Lexeme.find_by!(headword: "apple")
      expect(apple).to have_attributes(pos: "noun", cefr_level: "a1")
      expect(apple.language.code).to eq("en")
    end

    it "skips blank headword with a warning" do
      allow(Rails.logger).to receive(:warn)

      described_class.call(data_dir: fixture_dir)

      expect(Rails.logger).to have_received(:warn).with(/Skipping blank headword/)
    end

    it "is idempotent — second run does not duplicate records" do
      described_class.call(data_dir: fixture_dir)

      expect { described_class.call(data_dir: fixture_dir) }.not_to change(Lexeme, :count)
    end
  end

  context "when file does not exist" do
    before { stub_const("ContentBootstrap::ImportOxfordLexemes::FILE", "oxford-5000-missing.csv") }

    it "raises with the file name" do
      expect { described_class.call }.to raise_error(RuntimeError, /oxford-5000/)
    end
  end
end
