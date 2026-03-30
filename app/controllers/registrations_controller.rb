class RegistrationsController < ApplicationController
  def new
    redirect_to dashboard_path if logged_in?
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      session[:user_id] = @user.id
      redirect_to dashboard_path, notice: t("registrations.flash.success")
    else
      flash.now[:alert] = t("registrations.flash.error")
      render :new, status: :unprocessable_content
    end
  end

  private

  def registration_params
    params.expect(user: %i[email password password_confirmation])
  end
end
