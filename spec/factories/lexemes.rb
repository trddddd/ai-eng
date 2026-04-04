FactoryBot.define do
  factory :lexeme do
    association :language
    sequence(:headword) { |n| "word#{n}" }
    pos { nil }
    cefr_level { nil }
  end
end
