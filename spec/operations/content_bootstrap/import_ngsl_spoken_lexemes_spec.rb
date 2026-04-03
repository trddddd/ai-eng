require "rails_helper"

RSpec.describe ContentBootstrap::ImportNgslSpokenLexemes do
  let(:fixture_dir) { Rails.root.join("spec/fixtures/files") }

  context "with fixture file" do
    before { stub_const("ContentBootstrap::ImportNgslSpokenLexemes::FILE", "ngsl-spoken-fixture.csv") }

    it "imports valid lexemes" do
      expect { described_class.call(data_dir: fixture_dir) }.to change(Lexeme, :count).by(2)

      expect(Lexeme.find_by(headword: "apple")).to be_present
      expect(Lexeme.find_by(headword: "cherry")).to be_present
    end

    it "skips blank headword with a warning" do
      allow(Rails.logger).to receive(:warn)

      described_class.call(data_dir: fixture_dir)

      expect(Rails.logger).to have_received(:warn).with(/Skipping blank headword/)
    end

    it "is idempotent" do
      described_class.call(data_dir: fixture_dir)

      expect { described_class.call(data_dir: fixture_dir) }.not_to change(Lexeme, :count)
    end
  end

  context "when file does not exist" do
    before { stub_const("ContentBootstrap::ImportNgslSpokenLexemes::FILE", "ngsl-spoken-1-2-missing.csv") }

    it "raises with the file name" do
      expect { described_class.call }.to raise_error(RuntimeError, /ngsl-spoken-1-2/)
    end
  end
end
