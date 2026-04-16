class UserLexemeState < ApplicationRecord
  belongs_to :user
  belongs_to :lexeme

  has_many :user_sense_coverages, dependent: :destroy
  has_many :user_context_family_coverages, dependent: :destroy

  validates :user_id, uniqueness: { scope: :lexeme_id }
  validates :covered_sense_count, numericality: { greater_than_or_equal_to: 0 }
  validates :total_sense_count, numericality: { greater_than_or_equal_to: 0 }
  validates :sense_coverage_pct, numericality: { in: 0.0..100.0 }
  validates :covered_family_count, numericality: { greater_than_or_equal_to: 0 }
  validates :total_family_count, numericality: { greater_than_or_equal_to: 0 }
  validates :family_coverage_pct, numericality: { in: 0.0..100.0 }
end
