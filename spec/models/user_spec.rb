require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires email" do
      user.email = nil
      expect(user).not_to be_valid
    end

    it "validates email format" do
      user.email = "not-an-email"
      expect(user).not_to be_valid
    end

    it "requires unique email (case-insensitive)" do
      create(:user, email: "test@example.com")
      user.email = "TEST@EXAMPLE.COM"
      expect(user).not_to be_valid
    end

    it "requires password on create" do
      user.password = nil
      user.password_confirmation = nil
      expect(user).not_to be_valid
    end

    it "requires minimum password length of 8 characters" do
      user.password = "short"
      expect(user).not_to be_valid
    end
  end

  describe "#authenticate" do
    let(:saved_user) { create(:user, password: "securepassword", password_confirmation: "securepassword") }

    it "returns user with correct password" do
      expect(saved_user.authenticate("securepassword")).to eq(saved_user)
    end

    it "returns false with wrong password" do
      expect(saved_user.authenticate("wrongpassword")).to be_falsey
    end
  end

  describe "email normalization" do
    it "downcases email before save" do
      saved_user = create(:user, email: "USER@EXAMPLE.COM")
      expect(saved_user.reload.email).to eq("user@example.com")
    end
  end
end
