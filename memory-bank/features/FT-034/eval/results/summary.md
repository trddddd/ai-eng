---
title: "FT-034: Eval Results Summary"
doc_kind: eval
doc_function: derived
purpose: "Результаты прогона eval suite для FT-034 attempt-1."
derived_from:
  - ../suite/happy-path.md
  - ../suite/edge-cases.md
  - ../suite/regression.md
status: active
audience: humans_and_agents
---

# FT-034: Eval Results — Attempt 1

**Date:** 2026-04-17
**Verdict:** ACCEPT
**Test run:** 53 examples, 0 failures, 90.54% line coverage

## Happy Path (6/6 PASS)

| ID | Status | Mapped Test |
|----|--------|------------|
| EVAL-HP-01 | PASS | record_answer_spec: "calls RecordCoverage on correct answer" + "updates UserLexemeState in same transaction" |
| EVAL-HP-02 | PASS | record_coverage_spec: "is new_sense_and_family when both dimensions are new" |
| EVAL-HP-03 | PASS | record_coverage_spec: "is new_sense when only sense is new" |
| EVAL-HP-04 | PASS | record_coverage_spec: "is reinforcement when both already covered" |
| EVAL-HP-05 | PASS | build_progress_spec: "returns expected bucket distribution for mixed data" |
| EVAL-HP-06 | PASS | record_answer_spec: "creates two ReviewLogs and two contributions when called twice" |

## Edge Cases (9/9 PASS)

| ID | Status | Mapped Test |
|----|--------|------------|
| EVAL-EC-01 | PASS | record_answer_spec: "does not call RecordCoverage on incorrect answer" |
| EVAL-EC-02 | PASS | record_coverage_spec: "treats NULL sense as already-covered, records new_family" |
| EVAL-EC-03 | PASS | record_coverage_spec: "treats NULL family as already-covered, records new_sense" |
| EVAL-EC-04 | PASS | record_coverage_spec: "produces 100% sense coverage with new_sense_and_family" |
| EVAL-EC-05 | PASS | build_progress_spec: "returns zeros when user has no data" |
| EVAL-EC-06 | PASS | build_progress_spec: "counts states with sense_coverage_pct = 0 as zero bucket" |
| EVAL-EC-07 | PASS | word_mastery_rake_spec: "does not duplicate LexemeReviewContribution on second run" |
| EVAL-EC-08 | PASS | record_answer_spec: "rolls back ReviewLog and contribution if RecordCoverage raises" |
| EVAL-OV-01 | PASS | record_coverage_spec: "second call does not create a duplicate contribution" |

## Regression (7/7 PASS)

| ID | Status | Mapped Test |
|----|--------|------------|
| EVAL-RG-01 | PASS | record_answer_spec: "schedules the card" |
| EVAL-RG-02 | PASS | record_answer_spec: "assigns Again rating" + "assigns Hard rating" |
| EVAL-RG-03 | PASS | word_mastery_rake_spec: "creates a LexemeReviewContribution per correct review log" |
| EVAL-RG-04 | PASS | word_mastery_rake_spec: "creates coverage records from correct review logs" |
| EVAL-RG-05 | PASS | All 53 tests instantiate models via FactoryBot — no ActiveRecord errors |
| EVAL-RG-06 | PASS | build_progress_spec: streak + daily_reviews tests (10 examples) |
| EVAL-RG-07 | PASS | record_answer_spec: "rolls back if schedule! fails" |

## Verification Artifacts

| Check | Location |
|-------|----------|
| CHK-01..05 | artifacts/ft-034/verify/chk-01/ .. chk-05/ |
| Layers review | artifacts/ft-034/verify/layers/report.md |
| Simplify review | artifacts/ft-034/verify/simplify/report.md |
