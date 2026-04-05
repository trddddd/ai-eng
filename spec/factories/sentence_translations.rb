FactoryBot.define do
  factory :sentence_translation do
    association :sentence
    association :target_language, factory: :language
    sequence(:text) { |n| "Перевод #{n}" }
  end
end
