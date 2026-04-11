class DashboardController < ApplicationController
  before_action :require_login

  def index
    @progress = Dashboard::BuildProgress.call(user: current_user)
  end
end
