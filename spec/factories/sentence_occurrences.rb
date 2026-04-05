FactoryBot.define do
  factory :sentence_occurrence do
    association :sentence
    association :lexeme
    form { "word" }
  end
end
