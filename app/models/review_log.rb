class ReviewLog < ApplicationRecord
  belongs_to :card
  has_one :lexeme_review_contribution, dependent: :destroy

  RATING_AGAIN = 1
  RATING_HARD  = 2
  RATING_GOOD  = 3
  RATING_EASY  = 4

  RATINGS = [RATING_AGAIN, RATING_HARD, RATING_GOOD, RATING_EASY].freeze

  RECALL_QUALITIES = %w[
    no_recall
    near_miss
    effortful_recall
    successful_recall
    automatic_recall
  ].freeze

  FAST_THRESHOLD_MS = 3_000
  SLOW_THRESHOLD_MS = 10_000
  NEAR_MISS_ACCURACY = 0.7

  RECALL_TO_RATING = {
    "no_recall" => RATING_AGAIN,
    "near_miss" => RATING_HARD,
    "effortful_recall" => RATING_HARD,
    "successful_recall" => RATING_GOOD,
    "automatic_recall" => RATING_EASY
  }.freeze

  validates :rating, inclusion: { in: RATINGS }
  validates :recall_quality, inclusion: { in: RECALL_QUALITIES }
  validates :correct, inclusion: { in: [true, false] }
  validates :reviewed_at, presence: true
  validates :attempts, numericality: { greater_than: 0 }
  validates :answer_accuracy, numericality: { in: 0.0..1.0 }, allow_nil: true

  scope :for_user, ->(user) { joins(:card).where(cards: { user_id: user.id }) }

  def self.compute_accuracy(answer_text, expected)
    return 0.0 if answer_text.blank?

    a = answer_text.strip.downcase
    e = expected.strip.downcase
    return 1.0 if a == e

    distance = DidYouMean::Levenshtein.distance(a, e)
    max_len = [a.length, e.length].max
    (1.0 - (distance.to_f / max_len)).clamp(0.0, 1.0)
  end

  def self.classify_speed(elapsed_ms)
    return :unknown if elapsed_ms.nil?
    return :fast    if elapsed_ms < FAST_THRESHOLD_MS
    return :slow    if elapsed_ms >= SLOW_THRESHOLD_MS

    :normal
  end

  def self.classify_recall(correct:, elapsed_ms: nil, answer_accuracy: nil)
    unless correct
      return "near_miss" if answer_accuracy && answer_accuracy >= NEAR_MISS_ACCURACY

      return "no_recall"
    end

    case classify_speed(elapsed_ms)
    when :fast then "automatic_recall"
    when :slow then "effortful_recall"
    else            "successful_recall"
    end
  end

  def self.compute_rating(recall_quality)
    RECALL_TO_RATING.fetch(recall_quality)
  end

  def self.streak_for(user, now: Time.current)
    dates = distinct_review_dates_for(user)
    today = now.to_date
    return 0 unless dates.first == today

    count = 0
    expected = today
    dates.each do |date|
      break if date != expected

      count += 1
      expected -= 1
    end
    count
  end

  def self.distinct_review_dates_for(user)
    for_user(user)
      .order(Arel.sql("DATE(reviewed_at) DESC"))
      .pluck(Arel.sql("DATE(reviewed_at)"))
      .uniq
  end

  def self.unique_cards_reviewed_on(user, date)
    for_user(user).where(reviewed_at: date.all_day).distinct.count(:card_id)
  end
end
