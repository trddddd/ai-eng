require "rails_helper"

RSpec.describe "ReviewSessions", type: :request do
  let(:user) { create(:user) }

  def login
    post login_path, params: { email: user.email, password: "password123" }
  end

  describe "GET /review" do
    it "redirects to login when not authenticated" do
      get review_path
      expect(response).to redirect_to(login_path)
    end

    context "when authenticated" do
      before { login }

      it "returns 200 with a due card" do
        create(:card, user: user, due: 1.hour.ago)
        get review_path
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 with empty state when no due cards" do
        get review_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("reviews.done_title"))
      end
    end
  end

  describe "POST /review" do
    it "redirects to login when not authenticated" do
      post review_path, params: { card_id: "anything" }
      expect(response).to redirect_to(login_path)
    end

    context "when authenticated" do
      before { login }

      it "records answer and returns turbo stream" do
        card = create(:card, user: user, due: 1.hour.ago)
        post review_path,
             params: { card_id: card.id, answer_text: card.form, elapsed_ms: "5000", attempts: "1" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(ReviewLog.last.card).to eq(card)
      end

      it "returns 404 for card belonging to another user" do
        other_user = create(:user)
        other_card = create(:card, user: other_user, due: 1.hour.ago)

        post review_path,
             params: { card_id: other_card.id, answer_text: "anything" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
