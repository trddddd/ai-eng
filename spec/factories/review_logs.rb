FactoryBot.define do
  factory :review_log do
    association :card
    rating { ReviewLog::RATING_GOOD }
    recall_quality { "successful_recall" }
    correct { true }
    answer_text { "running" }
    answer_accuracy { 1.0 }
    elapsed_ms { 5_000 }
    attempts { 1 }
    backspace_count { 0 }
    reviewed_at { Time.current }
  end
end
