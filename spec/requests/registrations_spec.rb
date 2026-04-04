require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /register" do
    it "returns 200" do
      get register_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects to dashboard if already logged in" do
      user = create(:user)
      post login_path, params: { email: user.email, password: "password123" }
      get register_path
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "POST /register" do
    it "creates account and redirects to dashboard" do
      post register_path, params: { user: { email: "new@example.com", password: "password123", password_confirmation: "password123" } }
      expect(response).to redirect_to(dashboard_path)
    end

    it "renders new with invalid params" do
      post register_path, params: { user: { email: "", password: "short", password_confirmation: "short" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
