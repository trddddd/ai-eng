FactoryBot.define do
  factory :user_sense_coverage do
    association :user
    association :sense
    first_correct_at { Time.current }
  end
end
