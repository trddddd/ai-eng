class Lexeme < ApplicationRecord
  CEFR_LEVELS = %w[a1 a2 b1 b2 c1].freeze

  belongs_to :language
  has_many :lexeme_glosses, dependent: :destroy

  validates :headword, presence: true
  validates :headword, uniqueness: { scope: :language_id }
  validates :cefr_level, inclusion: { in: CEFR_LEVELS }, allow_nil: true
end
