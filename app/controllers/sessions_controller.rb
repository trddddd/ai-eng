class SessionsController < ApplicationController
  def new
    redirect_to review_path if logged_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase)

    if user&.authenticate(params[:password])
      login(user)
    else
      flash.now[:alert] = t("sessions.flash.invalid")
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: t("sessions.flash.signed_out")
  end

  private

  def login(user)
    reset_session
    session[:user_id] = user.id
    redirect_to review_path, notice: t("sessions.flash.success")
  end
end
