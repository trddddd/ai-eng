class UserSenseCoverage < ApplicationRecord
  belongs_to :user
  belongs_to :sense

  validates :user_id, uniqueness: { scope: :sense_id }
  validates :first_correct_at, presence: true
end
