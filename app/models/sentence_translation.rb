class SentenceTranslation < ApplicationRecord
  belongs_to :sentence
  belongs_to :target_language, class_name: "Language"

  validates :text, presence: true
  validates :sentence_id, uniqueness: { scope: :target_language_id }
end
