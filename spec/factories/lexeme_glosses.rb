FactoryBot.define do
  factory :lexeme_gloss do
    association :lexeme
    association :target_language, factory: :language
    sequence(:gloss) { |n| "gloss #{n}" }
  end
end
