require "rails_helper"

RSpec.describe ContextFamily, type: :model do
  let(:context_family) { build(:context_family) }

  it "has a valid factory" do
    expect(context_family).to be_valid
  end

  it "requires a name" do
    context_family.name = nil
    expect(context_family).not_to be_valid
    expect(context_family.errors[:name]).to include("не может быть пустым")
  end

  it "requires a unique name" do
    create(:context_family, name: "test")
    duplicate = build(:context_family, name: "test")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include("уже существует")
  end
end
