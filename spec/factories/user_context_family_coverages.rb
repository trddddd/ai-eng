FactoryBot.define do
  factory :user_context_family_coverage do
    association :user
    association :lexeme
    association :context_family
    first_correct_at { Time.current }
  end
end
