class Sentence < ApplicationRecord
  belongs_to :language
  has_many :sentence_translations, dependent: :restrict_with_exception
  has_many :sentence_occurrences, dependent: :restrict_with_exception

  validates :text, presence: true
  validates :source, presence: true
  validates :text, uniqueness: { scope: :language_id }
  validate :text_has_no_cloze_placeholder

  # For Tatoeba sentences, fallback to tatoeba_id when audio_id is nil
  # Tatoeba audio URLs use the sentence ID as the audio file ID
  def audio_id_with_fallback
    audio_id || (source == "tatoeba" ? tatoeba_id : nil)
  end

  private

  def text_has_no_cloze_placeholder
    errors.add(:text, "must not contain ____") if text&.include?("____")
  end
end
