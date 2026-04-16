FactoryBot.define do
  factory :user_lexeme_state do
    association :user
    association :lexeme
    covered_sense_count { 0 }
    total_sense_count { 0 }
    sense_coverage_pct { 0.0 }
    covered_family_count { 0 }
    total_family_count { 0 }
    family_coverage_pct { 0.0 }
    last_covered_at { nil }
  end
end
