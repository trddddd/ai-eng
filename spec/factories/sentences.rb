FactoryBot.define do
  factory :sentence do
    association :language
    sequence(:text) { |n| "Sentence number #{n}" }
    source { "quizword" }
  end
end
