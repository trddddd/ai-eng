class SentenceOccurrence < ApplicationRecord
  belongs_to :sentence
  belongs_to :lexeme

  validates :form, presence: true
  validates :sentence_id, uniqueness: { scope: :lexeme_id }

  def cloze_text
    sentence.text.sub(form, "____")
  end
end
