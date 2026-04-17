# Start: attempt-1

## State Snapshot

- Feature: `FT-034: Review Pipeline v2 + Word Progress Dashboard`
- Stage: Execution (delivery_status → in_progress)
- Previous attempts: none
- Base branch: `main` @ `996306f`
- Worktree: `/Users/xtrmdk/work/lingvize-ft-034-att1` on `feat/ft-034-att1`

## Pre-Attempt Checklist

- [x] `feature.md` прочитан, `delivery_status = planned` → переведём в `in_progress`
- [x] `implementation-plan.md` прочитан; первый незакрытый STEP — `STEP-01`
- [x] Eval suite существует (`happy-path.md`, `edge-cases.md`, `regression.md`)
- [x] Eval criteria: `strategy.md` зафиксировал Decision Predicates (accept / revise / escalate / split)
- [x] Evidence pre-declaration заполнена (`EVID-01..05`, `EVID-EVAL-SUITE`, `EVID-LAYERS`, `EVID-SIMPLIFY`, `EVID-EVAL-RUN`)
- [x] Orchestration pattern зафиксирован в `meta.yaml` (sequential)
- [x] Human Control Map заполнена (`HC-01` pending, `HC-02` skipped-unless-needed)
- [x] Все `PRE-*` выполнены: PRE-GIT (worktree создан), PRE-ASM-01 (FT-031 done), PRE-ASM-02 (FT-029 done)
- [x] Текущий checkout находится внутри `worktree_path`

## What to do this attempt

- [ ] REQ-01: интеграция `WordMastery::RecordCoverage` в `Reviews::RecordAnswer`
- [ ] REQ-02: новая сущность `LexemeReviewContribution` + миграция + модель + index
- [ ] REQ-03: `RecordCoverage` создаёт `LexemeReviewContribution` в одной transaction
- [ ] REQ-04: `Dashboard::BuildProgress` обогащена word-level bucket counts
- [ ] REQ-05: Dashboard view — word progress card (3 buckets + empty state FM-04)
- [ ] CHK-01..CHK-05: все спеки зелёные, rubocop зелёный

## Notes

- `CON-05`: удаляем `ActiveRecord::Base.transaction` из `RecordCoverage`; outer transaction — в `RecordAnswer` и wrapper в backfill (`STEP-06`)
- `FM-03` / `NEG-04`: идемпотентность через early-return при existing `LexemeReviewContribution` для `review_log_id`
- `ASM-03`: contribution_type вычисляется ДО upsert по truth table на (UserSenseCoverage, UserContextFamilyCoverage)
