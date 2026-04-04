require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }

  describe "GET /login" do
    it "returns 200" do
      get login_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects to dashboard if already logged in" do
      post login_path, params: { email: user.email, password: "password123" }
      get login_path
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "POST /login" do
    it "logs in with valid credentials" do
      post login_path, params: { email: user.email, password: "password123" }
      expect(response).to redirect_to(dashboard_path)
    end

    it "renders new with invalid credentials" do
      post login_path, params: { email: "wrong@example.com", password: "wrong" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /logout" do
    it "logs out and redirects" do
      post login_path, params: { email: user.email, password: "password123" }
      delete logout_path
      expect(response).to redirect_to(login_path)
    end
  end
end
