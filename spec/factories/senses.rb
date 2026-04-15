FactoryBot.define do
  factory :sense do
    association :lexeme
    definition { "A sense definition" }
    pos { "noun" }
    sense_rank { 1 }
    examples { [] }
    source { "wordnet" }
    lexical_domain { "noun.cognition" }
    sequence(:external_id) { |n| 10_000 + n }
  end
end
