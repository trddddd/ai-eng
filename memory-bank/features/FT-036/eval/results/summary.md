---
title: "FT-036: Eval Results"
doc_kind: eval
doc_function: derived
purpose: "Eval results for FT-036 Session Builder v2 — Dual-Level Scheduling."
derived_from:
  - ../strategy.md
  - ../../feature.md
status: active
audience: humans_and_agents
---

# Eval Results: FT-036

## Summary

| Layer | Pass | Fail | Issues |
| --- | --- | --- | --- |
| Hygiene | ✅ | — | `bundle exec rubocop` — 0 offenses (115 files) |
| Plan coverage | ✅ | — | REQ-01–REQ-06 → STEP-01/02; all SC-*/NEG-* have matching tests |
| Acceptance | ✅ | — | CHK-01, CHK-02, CHK-03 all pass |
| Workflow | ✅ | — | All STEP-* executed in order, /layers:review + /simplify done |

## Detail: Happy Path (EVAL-HP-*)

| Case | SC-ref | Expected | Actual | Result |
| --- | --- | --- | --- | --- |
| EVAL-HP-01 | SC-01 | 10 card debt cards, no word debt | 10 card debt, word debt skipped | ✅ pass |
| EVAL-HP-02 | SC-02 | 5 cards: 3 card debt + 2 word debt | 5 cards returned, last 2 STATE_NEW | ✅ pass |
| EVAL-HP-03 | SC-03 | Occurrence from uncovered family selected | Uncovered family occurrence selected | ✅ pass |
| EVAL-HP-04 | SC-05 | Sense fallback when all families covered | Uncovered sense occurrence selected | ✅ pass |
| EVAL-HP-05 | SC-02 | Integration: BuildSession → RecordAnswer → coverage update | Covered by existing RecordAnswer + RecordCoverage specs (338 examples green) | ✅ pass |

## Detail: Edge Cases (EVAL-EC-*)

| Case | NEG-ref | Expected | Actual | Result |
| --- | --- | --- | --- | --- |
| EVAL-EC-01 | NEG-01 | No word debt for user without ULS | 3 card debt only | ✅ pass |
| EVAL-EC-02 | NEG-02 | Skip lexeme with existing card | Empty result | ✅ pass |
| EVAL-EC-03 | NEG-03 | Skip NULL context_family occurrences | Empty result | ✅ pass |
| EVAL-EC-04 | NEG-04 | No raise on unique constraint | No error raised | ✅ pass |
| EVAL-EC-05 | NEG-05 | No word debt when remaining_slots=0 | Card.count unchanged | ✅ pass |
| EVAL-EC-06 | NEG-06 | One word debt card per lexeme | Exactly 1 card for lexeme | ✅ pass |
| EVAL-EC-07 | NEG-07 | Empty array, no side effects for limit:0 | Empty, Card.count unchanged | ✅ pass |
| EVAL-EC-08 | SC-04 | Only card debt when fully covered | 1 due card returned | ✅ pass |

## Detail: Regression (EVAL-RG-*)

| Case | Expected | Actual | Result |
| --- | --- | --- | --- |
| EVAL-RG-01 | Card debt v1 behavior preserved | Existing 5 card debt tests green | ✅ pass |
| EVAL-RG-02 | RecordAnswer works after BuildSession v2 | record_answer_spec green | ✅ pass |
| EVAL-RG-03 | Dashboard::BuildProgress works | build_progress_spec green | ✅ pass |
| EVAL-RG-04 | RecordCoverage for word-debt card | Covered by existing pipeline specs | ✅ pass |
| EVAL-RG-05 | Full suite green | 338 examples, 0 failures | ✅ pass |

## Evidence

| Evidence ID | Check | Artifact | Status |
| --- | --- | --- | --- |
| EVID-01 | CHK-01 | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` — card debt: 6 examples, 0 failures | ✅ collected |
| EVID-02 | CHK-02 | `bundle exec rspec spec/operations/reviews/build_session_spec.rb` — word debt + edge: 14 examples, 0 failures | ✅ collected |
| EVID-03 | CHK-03 | `bundle exec rspec` — 338 examples, 0 failures, coverage 90.76% | ✅ collected |
| EVID-EVAL-SUITE | CP-EVAL-SUITE | eval/suite/*.md exist and cover SC-*/NEG-* | ✅ collected |
| EVID-LAYERS | CP-LAYERS | /layers:review — no violations, 3 advisory suggestions | ✅ collected |
| EVID-SIMPLIFY | CP-SIMPLIFY | /simplify — 5 issues fixed (dedup finders, constants, queries) | ✅ collected |
| EVID-EVAL-RUN | CP-EVAL-RUN | This summary | ✅ |

## Verification Steps Executed

| Step | Status |
| --- | --- |
| STEP-EVAL-VERIFY | ✅ Eval suite verified |
| STEP-01 | ✅ Dual-level BuildSession implemented |
| STEP-02 | ✅ 20 tests written, all green |
| STEP-03 | ✅ 338 examples, 0 failures; rubocop 0 offenses |
| STEP-LAYERS-REVIEW | ✅ No critical violations |
| STEP-SIMPLIFY | ✅ 5 improvements applied |
| STEP-EVAL-RUN | ✅ This eval |

## Decision

**Accept** — all critical eval cases passed; all CHK-* have pass verdicts with concrete evidence; hygiene, acceptance, and regression layers pass; /layers:review and /simplify completed without blocking issues.
