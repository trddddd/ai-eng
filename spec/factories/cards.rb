FactoryBot.define do
  factory :card do
    association :user
    association :sentence_occurrence
    due { Time.current }
    stability { 0.0 }
    difficulty { 0.0 }
    elapsed_days { 0 }
    scheduled_days { 0 }
    reps { 0 }
    lapses { 0 }
    state { Card::STATE_NEW }
    last_review { nil }
  end
end
