require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    it "redirects to login when not authenticated" do
      get dashboard_path
      expect(response).to redirect_to(login_path)
    end

    it "returns 200 when authenticated" do
      user = create(:user)
      post login_path, params: { email: user.email, password: "password123" }
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end

    context "when user has no review history (zero state)" do
      it "renders all three progress cards with zero values" do
        user = create(:user)
        post login_path, params: { email: user.email, password: "password123" }
        get dashboard_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("0 / 50")
      end
    end

    context "when user has review history" do
      it "renders progress cards with data from the operation" do
        user = create(:user)
        card = create(:card, user: user, state: Card::STATE_REVIEW)
        create(:review_log, card: card, reviewed_at: Time.current)

        post login_path, params: { email: user.email, password: "password123" }
        get dashboard_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("1 / 50")
      end
    end
  end
end
