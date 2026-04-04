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
  end
end
