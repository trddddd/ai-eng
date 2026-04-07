class ReviewSessionsController < ApplicationController
  before_action :require_login

  def show
    @cards = Reviews::BuildSession.call(user: current_user)
    @card = @cards.first
  end

  # rubocop:disable Metrics/AbcSize
  def create
    @card = current_user.cards.find(params[:card_id])
    answer_text = params[:answer_text].to_s.strip

    @review_log = Reviews::RecordAnswer.call(
      card: @card,
      correct: answer_correct?(answer_text, @card),
      answer_text: answer_text,
      elapsed_ms: positive_int(params[:elapsed_ms]),
      attempts: positive_int(params[:attempts]) || 1,
      backspace_count: positive_int(params[:backspace_count])
    )

    @next_cards = Reviews::BuildSession.call(user: current_user)
    @next_card = @next_cards.first
  end
  # rubocop:enable Metrics/AbcSize

  private

  def answer_correct?(answer_text, card)
    answer_text.downcase == card.form.downcase
  end

  def positive_int(value)
    v = value&.to_i
    v&.positive? ? v : nil
  end
end
