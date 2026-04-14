class SentenceOccurrence < ApplicationRecord
  belongs_to :sentence
  belongs_to :lexeme
  belongs_to :sense, optional: true
  belongs_to :context_family, optional: true

  has_many :cards, dependent: :restrict_with_exception

  validates :form, presence: true
  validates :sentence_id, uniqueness: { scope: :lexeme_id }

  def cloze_text
    sentence.text.sub(form, "____")
  end
end
