---
title: Testing Policy
doc_kind: engineering
doc_function: canonical
purpose: Testing policy Lingvize: RSpec, SimpleCov, FactoryBot, CI. Читать перед написанием или ревью тестов.
derived_from:
  - ../dna/governance.md
  - ../flows/feature-flow.md
status: active
canonical_for:
  - repository_testing_policy
  - feature_test_case_inventory_rules
  - automated_test_requirements
  - sufficient_test_coverage_definition
  - manual_only_verification_exceptions
  - simplify_review_discipline
  - verification_context_separation
must_not_define:
  - feature_acceptance_criteria
  - feature_scope
audience: humans_and_agents
---

# Testing Policy

## Project Testing Stack

- **Framework:** RSpec (`bundle exec rspec`)
- **Data:** FactoryBot (factories в `spec/factories/`)
- **Coverage:** SimpleCov, минимум 80% (`spec/spec_helper.rb`)
- **Local commands:** `bundle exec rspec` (тесты), `bundle exec rubocop` (lint)
- **CI:** GitHub Actions `rails.yml` — параллельные jobs: lint (RuboCop) + test (RSpec + SimpleCov)
- **CI artifact:** `coverage-report` (upload-artifact, 7 дней, `if: always()`)
- **DB в CI:** PostgreSQL 18-alpine service

## Core Rules

- Любое изменение поведения, которое можно проверить детерминированно, обязано получить automated regression coverage.
- Любой новый или измененный contract обязан получить contract-level automated verification.
- Любой bugfix обязан добавить regression test на воспроизводимый сценарий.
- Required automated tests считаются закрывающими риск только если они проходят локально и в CI.
- Manual-only verify допустим только как явное исключение.

## Ownership Split

- `feature.md` владеет test case inventory: `SC-*`, `NEG-*`, `CHK-*`, `EVID-*`.
- `implementation-plan.md` владеет стратегией исполнения: какие test surfaces добавляются, какие gaps временно manual-only.

## Feature Flow Expectations

- к `Design Ready` — `feature.md` фиксирует test case inventory;
- к `Plan Ready` — `implementation-plan.md` содержит Test Strategy;
- к `Done` — тесты добавлены, `bundle exec rspec` и `bundle exec rubocop` зелёные.

## Sufficient Coverage

- Покрыт changed behavior и regression path.
- Покрыты новые/изменённые contracts, events, schema.
- Покрыты failure modes из `FM-*`.
- Покрыты negative/edge scenarios, если они меняют verdict.
- Процент line coverage сам по себе недостаточен: нужен scenario- и contract-level coverage.

## Manual-Only Exceptions

- Внешние CDN/API (Tatoeba audio, Quizword scraping) — stub в тестах, manual verify для CORS/connectivity.
- Docker Compose зависимости (pg_dump/pg_restore) — stub в тестах.
- Visual UI проверки (дизайн-система) — ручной проход по reference.html.

## Simplify Review

Отдельный проход после функционального тестирования:
- premature abstractions, глубокая вложенность, дублирование, dead code
- три похожие строки лучше premature abstraction

## Project-Specific Conventions

- Новые тесты: `spec/models/`, `spec/operations/`, `spec/requests/`
- Factories: `spec/factories/` (FactoryBot)
- DB: реальная PostgreSQL в тестах (не SQLite)
- Перед handoff агент обязан прогнать: `bundle exec rspec` + `bundle exec rubocop`
- **Перед написанием новых спеков:** прочитать хотя бы один существующий спек того же типа, чтобы соответствовать конвенциям проекта. В этом проекте model specs используют `subject(:model) { build(:model) }`, оборачивают кейсы в `describe "validations"`, мутируют subject вместо сборки с невалидными attrs
