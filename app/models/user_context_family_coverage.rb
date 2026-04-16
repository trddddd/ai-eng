class UserContextFamilyCoverage < ApplicationRecord
  belongs_to :user
  belongs_to :lexeme
  belongs_to :context_family

  validates :user_id, uniqueness: { scope: %i[lexeme_id context_family_id] }
  validates :first_correct_at, presence: true
end
