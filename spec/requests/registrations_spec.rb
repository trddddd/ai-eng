require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /register" do
    it "returns 200" do
      get register_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects to review if already logged in" do
      user = create(:user)
      post login_path, params: { email: user.email, password: "password123" }
      get register_path
      expect(response).to redirect_to(review_path)
    end
  end

  describe "POST /register" do
    it "creates account and redirects to review" do
      post register_path, params: { user: { email: "new@example.com", password: "password123", password_confirmation: "password123" } }
      expect(response).to redirect_to(review_path)
    end

    it "renders new with invalid params" do
      post register_path, params: { user: { email: "", password: "short", password_confirmation: "short" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    context "when A1 content exists" do
      let(:en) { create(:language, code: "en", name: "English") }
      let(:ru) { create(:language, code: "ru", name: "Russian") }

      before do
        lexeme = create(:lexeme, language: en, cefr_level: "a1", headword: "hello")
        sentence = create(:sentence, language: en, text: "I said hello.")
        create(:sentence_translation, sentence: sentence, target_language: ru, text: "Перевод")
        create(:sentence_occurrence, sentence: sentence, lexeme: lexeme, form: "hello")
      end

      it "creates cards for the new user" do
        expect do
          post register_path, params: { user: { email: "new@example.com", password: "password123", password_confirmation: "password123" } }
        end.to change(Card, :count).by(1)
      end
    end

    context "when BuildStarterDeck raises an error" do
      before do
        allow(Cards::BuildStarterDeck).to receive(:call).and_raise(StandardError, "oops")
      end

      it "still creates the user and redirects to review" do
        post register_path, params: { user: { email: "new@example.com", password: "password123", password_confirmation: "password123" } }
        expect(response).to redirect_to(review_path)
        expect(User.find_by(email: "new@example.com")).to be_present
      end
    end
  end
end
