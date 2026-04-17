# Simplify Review — FT-034

**Date:** 2026-04-17
**Verdict:** clean (advisory items fixed)

## Agents

| Agent | Status |
|-------|--------|
| Code Reuse | rate-limited (skipped) |
| Code Quality | completed |
| Efficiency | rate-limited (manual review) |

## Findings & Actions

### Fixed (advisory)

1. **RecordCoverage parameter sprawl** — `user`, `lexeme`, `occurrence` threaded through 6 private methods as params. Memoized as `@user`, `@lexeme`, `@occurrence` on the instance; private methods now take zero args.

2. **Progress struct redundant field** — `total_words_tracked` was a stored field derivable from `words_zero_coverage + words_partial_coverage + words_full_coverage`. Converted to a computed method on the Struct.

### Accepted (nit, no action)

3. **Rake task duplicate idempotency guard** — `next if LexemeReviewContribution.exists?(...)` duplicates the operation's internal guard. Kept intentionally: saves transaction overhead per already-processed row during backfill.

4. **CONTRIBUTION_TYPE_BY_NEWNESS constant placement** — between `call` and `private`. Acceptable per Ruby convention (constants are class-level, not instance-scoped).

5. **String contribution types vs named constants** — matches existing codebase pattern (`RECALL_QUALITIES`, `RATINGS`). Model validates inclusion.

6. **word_buckets plucks all rows to Ruby** — O(n) transfer vs SQL CASE GROUP BY. Acceptable at current scale (<100 lexemes/user). Flagged for future optimization if user lexeme counts grow to 10k+.

7. **RecordCoverage no inner transaction** — by design (CON-05). Callers (RecordAnswer, rake task) wrap in transaction.

## Test Verification

```
53 examples, 0 failures
rubocop: 3 files inspected, no offenses detected
```
