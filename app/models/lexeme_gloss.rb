class LexemeGloss < ApplicationRecord
  belongs_to :lexeme
  belongs_to :target_language, class_name: "Language"

  validates :gloss, presence: true
  validates :gloss, uniqueness: { scope: %i[lexeme_id target_language_id] }
end
