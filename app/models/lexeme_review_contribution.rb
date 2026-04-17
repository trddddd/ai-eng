class LexemeReviewContribution < ApplicationRecord
  CONTRIBUTION_TYPES = %w[
    new_sense
    new_family
    new_sense_and_family
    reinforcement
  ].freeze

  belongs_to :review_log
  belongs_to :user
  belongs_to :lexeme
  belongs_to :sense, optional: true
  belongs_to :context_family, optional: true

  validates :review_log_id, uniqueness: true
  validates :contribution_type, inclusion: { in: CONTRIBUTION_TYPES }
end
