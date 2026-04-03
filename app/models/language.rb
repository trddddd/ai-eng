class Language < ApplicationRecord
  has_many :lexemes, dependent: :destroy
  has_many :targeted_lexeme_glosses,
           class_name: "LexemeGloss",
           foreign_key: :target_language_id,
           inverse_of: :target_language,
           dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
