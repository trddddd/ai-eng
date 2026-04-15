class Sense < ApplicationRecord
  belongs_to :lexeme
  has_many :sentence_occurrences, dependent: :restrict_with_error

  validates :definition, presence: true
  validates :pos, presence: true
  validates :source, presence: true
end
