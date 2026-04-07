require "rails_helper"

RSpec.describe "Cards", type: :request do
  let(:user) { create(:user) }

  def login
    post login_path, params: { email: user.email, password: "password123" }
  end

  describe "POST /cards/:id/master" do
    it "redirects to login when not authenticated" do
      card = create(:card, user: user)
      post master_card_path(card)
      expect(response).to redirect_to(login_path)
    end

    context "when authenticated" do
      before { login }

      it "masters the card and returns turbo stream" do
        card = create(:card, user: user, due: 1.hour.ago)
        post master_card_path(card), headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(card.reload).to be_mastered
      end

      it "returns 404 for card belonging to another user" do
        other_user = create(:user)
        other_card = create(:card, user: other_user)

        post master_card_path(other_card)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
