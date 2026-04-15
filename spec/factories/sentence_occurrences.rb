FactoryBot.define do
  factory :sentence_occurrence do
    association :sentence
    association :lexeme
    association :context_family
    form { "word" }

    after(:build) do |occurrence|
      occurrence.sense ||= FactoryBot.build(:sense, lexeme: occurrence.lexeme)
    end

    before(:create) do |occurrence|
      occurrence.sense.save! unless occurrence.sense.persisted?
    end
  end
end
