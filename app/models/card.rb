class Card < ApplicationRecord
  belongs_to :user
  belongs_to :sentence_occurrence
  has_many :review_logs, dependent: :destroy

  delegate :lexeme, :sentence, :form, :cloze_text, to: :sentence_occurrence

  scope :due_for_review, lambda { |user, now: Time.current|
    where(user: user, mastered_at: nil).where(due: ..now)
  }

  scope :learned, -> { where("state = ? OR mastered_at IS NOT NULL", STATE_REVIEW) }

  STATE_NEW        = 0
  STATE_LEARNING   = 1
  STATE_REVIEW     = 2
  STATE_RELEARNING = 3

  validates :due, presence: true
  validates :state, inclusion: { in: [STATE_NEW, STATE_LEARNING, STATE_REVIEW, STATE_RELEARNING] }
  validates :sentence_occurrence_id, uniqueness: { scope: :user_id }

  FSRS_ATTRS = %i[due stability difficulty elapsed_days scheduled_days reps lapses state last_review].freeze

  def to_fsrs_card
    Fsrs::Card.new.tap do |fsrs|
      FSRS_ATTRS.each { |attr| fsrs.public_send(:"#{attr}=", public_send(attr)) }
    end
  end

  def apply_fsrs_card!(fsrs_card)
    update!(
      due: fsrs_card.due,
      stability: fsrs_card.stability,
      difficulty: fsrs_card.difficulty,
      elapsed_days: fsrs_card.elapsed_days,
      scheduled_days: fsrs_card.scheduled_days,
      reps: fsrs_card.reps,
      lapses: fsrs_card.lapses,
      state: fsrs_card.state,
      last_review: fsrs_card.last_review
    )
  end

  def schedule!(rating:, now: Time.current)
    scheduler = Fsrs::Scheduler.new
    fsrs_card = to_fsrs_card
    results = scheduler.repeat(fsrs_card, now.utc)
    apply_fsrs_card!(results[rating].card)
  end

  def master!(now: Time.current)
    update!(mastered_at: now)
  end

  def mastered?
    mastered_at.present?
  end
end
