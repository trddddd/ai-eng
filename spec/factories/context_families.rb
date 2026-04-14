FactoryBot.define do
  factory :context_family do
    sequence(:name) { |n| "context_family_#{n}" }
    description { "Context family description" }
  end
end
