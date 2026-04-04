FactoryBot.define do
  factory :language do
    sequence(:code) { |n| "lang#{n}" }
    sequence(:name) { |n| "Language #{n}" }
  end
end
