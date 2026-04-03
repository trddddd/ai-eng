require "rails_helper"

RSpec.describe ContentBootstrap::ImportNgslCoreLexemes do
  let(:fixture_dir) { Rails.root.join("spec/fixtures/files") }

  context "with fixture file" do
    before { stub_const("ContentBootstrap::ImportNgslCoreLexemes::FILE", "ngsl-core-fixture.csv") }

    it "imports valid lexemes skipping comment lines" do
      expect { described_class.call(data_dir: fixture_dir) }.to change(Lexeme, :count).by(2)

      expect(Lexeme.find_by(headword: "apple")).to be_present
      expect(Lexeme.find_by(headword: "cherry")).to be_present
    end

    it "stores nil pos and cefr_level" do
      described_class.call(data_dir: fixture_dir)

      expect(Lexeme.find_by!(headword: "apple")).to have_attributes(pos: nil, cefr_level: nil)
    end

    it "is idempotent" do
      described_class.call(data_dir: fixture_dir)

      expect { described_class.call(data_dir: fixture_dir) }.not_to change(Lexeme, :count)
    end
  end

  context "when file does not exist" do
    before { stub_const("ContentBootstrap::ImportNgslCoreLexemes::FILE", "ngsl-1-2-missing.csv") }

    it "raises with the file name" do
      expect { described_class.call }.to raise_error(RuntimeError, /ngsl-1-2/)
    end
  end
end
