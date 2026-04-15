class ContextFamily < ApplicationRecord
  has_many :sentence_occurrences, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
