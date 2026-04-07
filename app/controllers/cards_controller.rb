class CardsController < ApplicationController
  before_action :require_login

  def master
    card = current_user.cards.find(params[:id])
    card.master!

    @next_cards = Reviews::BuildSession.call(user: current_user)
    @next_card = @next_cards.first
    render "review_sessions/create"
  end
end
