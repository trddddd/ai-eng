class RegistrationsController < ApplicationController
  def new
    redirect_to dashboard_path if logged_in?
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      build_starter_deck(@user)
      reset_session
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

  def build_starter_deck(user)
    Cards::BuildStarterDeck.call(user)
  rescue StandardError => e
    backtrace = e.backtrace&.first(5)&.join("\n")
    Rails.logger.error("BuildStarterDeck failed for user #{user.id}: #{e.class}: #{e.message}\n#{backtrace}")
  end
end
