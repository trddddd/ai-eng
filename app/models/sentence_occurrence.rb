class SentenceOccurrence < ApplicationRecord
  belongs_to :sentence
  belongs_to :lexeme

  has_many :cards, dependent: :restrict_with_exception

  validates :form, presence: true
  validates :sentence_id, uniqueness: { scope: :lexeme_id }

  def cloze_text
    sentence.text.sub(form, "____")
  end
end
