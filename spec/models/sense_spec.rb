require "rails_helper"

RSpec.describe Sense, type: :model do
  let(:sense) { build(:sense) }

  it "has a valid factory" do
    expect(sense).to be_valid
  end

  it "requires a definition" do
    sense.definition = nil
    expect(sense).not_to be_valid
    expect(sense.errors[:definition]).to include("не может быть пустым")
  end

  it "requires a pos" do
    sense.pos = nil
    expect(sense).not_to be_valid
    expect(sense.errors[:pos]).to include("не может быть пустым")
  end

  it "requires a source" do
    sense.source = nil
    expect(sense).not_to be_valid
    expect(sense.errors[:source]).to include("не может быть пустым")
  end

  it "belongs to a lexeme" do
    expect(sense.lexeme).to be_present
  end

  it "defaults source to 'wordnet'" do
    expect(described_class.new(definition: "test definition", pos: "noun").source).to eq("wordnet")
  end

  it "defaults sense_rank to 1" do
    expect(described_class.new(definition: "test definition", pos: "noun").sense_rank).to eq(1)
  end

  it "defaults examples to empty array" do
    expect(described_class.new(definition: "test definition", pos: "noun").examples).to eq([])
  end
end
