# Testing Plan

## Objectives
- Prove correctness of callouts, parsing, and persistence.
- Verify queueable chaining + idempotency (daily upsert-by-key).
- Validate cleanup/retention behavior.
- Ensure friendly error handling per Integration spec.
- Keep tests fast, isolated, and deterministic.

## Test Tooling & Conventions
- **Factories**: `CurrencyFactory`, `ExchangeRateFactory`, `SettingsFactory`.
- **HTTP Mocks**: `FreeCurrencyApiMock` implementing `HttpCalloutMock` with switchable scenarios.
- **Log Helper**: `Log.info(...)` / `Log.error(...)` is no-op in tests unless you assert log rows.
- **Test Data Isolation**: Use `@testSetup` to seed Currency__c and org settings.
- **Naming**: `Given_When_Then` style; one behavior per test.

---

## Test Matrix (Essentials)

| Area | Case | Expected |
|---|---|---|
| **Currencies** | `/v1/currencies` happy path | New codes inserted, removed codes deactivated, counts returned |
|  | No changes | No DML (assert zero upserts/deactivations) |
|  | Malformed payload | Fail with handled error; no partial DML |
| **Latest Rates** | Single base, chunked quotes | Upserts `ExchangeRate__c` with `Key__c = Base|Quote|Rate_Date__c` |
|  | Multi-base fan-out | One call per base; all quotes covered |
|  | Idempotency (re-run same day) | No duplicates; same keys updated 0 or 1 row affected |
|  | Self-pair excluded | No `Base=Quote` rows created |
| **Historical (UI on-demand)** | Date param OK | Returns rate to UI; no persistence when persistence disabled |
|  | Invalid date | Surfaces friendly 422 message; no DML |
| **Chaining** | Queueable chain order | `FetchCurrencies → (if persist) FetchLatestRates → DeleteOldRates` |
|  | Persist flag = false | Only currencies job runs; no rates persisted |
| **Cleanup** | Retention = N days | Deletes only rows older than N |
|  | Large delete | Escalation to Batch path when >10k rows (assert batch enqueued) |
| **Errors** | 401 | Surfaces admin-friendly message; stops chain appropriately |
|  | 422 | Skips bad request; no retry; no DML |
|  | 429 | Backoff behavior invoked (assert reschedule intent / state captured) |
|  | 5xx | Retries up to configured attempts; then handled fail |
| **Settings/Validation** | Retention_Days__c required > 0 | Validation enforced; job honors it |
|  | Allowed codes filter | Only allowed quotes requested/persisted |
| **Security** | Named Credential used | No raw host/keys in code; header present via NC |
| **Logs (minimal)** | Log rows written | Optional: assert 1 log per API call + 1 per job step |

---

## Unit Tests (Apex)

### 1) Currency Service
- **Happy path**: Mock `/v1/currencies` with 3 new, 2 unchanged, 1 missing → assert 3 inserts, 1 deactivate.
- **No changes**: Mock identical payload → assert 0 DML.
- **Malformed payload**: Return invalid JSON → assert thrown handled → no DML.

### 2) Rates Service
- **Happy path**: Mock `/v1/latest` for Base=USD with quotes chunked (e.g., 80 codes → 2 calls). Assert all rows exist, keys composed correctly.
- **Idempotent re-run**: Run twice same day → row count unchanged; no dupes by `Key__c`.
- **Multi-base**: Seed 3 bases; assert 3 API calls with respective `base_currency`.
- **Self-pair**: Ensure USD→USD is never persisted.
- **Historical**: With persistence disabled, call UI method → returns values, no `ExchangeRate__c` DML.

### 3) Queueable Chain
- **Persist=true**: Enqueue `FetchCurrencies` → verify it enqueues `FetchLatestRates` (spy via a flag or log entry) → then `DeleteOldRates`.
- **Persist=false**: Enqueue `FetchCurrencies` → verify no follow-ups.
- **Error in currencies**: Simulate 5xx → verify retries/backoff or fail path; ensure no downstream enqueue.

### 4) Cleanup
- **Retention = 3**: Seed dates `T-4..T` → only `T-4` deleted.
- **>10k delete**: Seed 11k old rows → verify Batch cleanup path is chosen.

### 5) Error Mapping
- **401**: Mock 401 → assert message mapping; no retry; chain stops.
- **422**: Mock invalid currency/date → handled, no retry, no DML.
- **429**: Mock 429 with/without `Retry-After` → assert backoff/reschedule behavior recorded.
- **5xx**: Mock 500 → retries then fail with friendly admin outcome.

---

## HTTP Mock Fixtures
Create small JSON fixture strings in a test utility class:
- `Currencies_Happy.json`, `Currencies_Empty.json`, `Currencies_Malformed.json`
- `Latest_USD_Chunk1.json`, `Latest_USD_Chunk2.json`, `Latest_EUR.json`
- `Historical_2025_10_15.json`
- Error wrappers: `Err401.json`, `Err422.json`, `Err429.json`, `Err500.json` (bodies optional; status code is key)

The `FreeCurrencyApiMock` switches by URL path + query and returns the appropriate payload/status.

---

## Performance & Limits (fast checks)
- Ensure each queueable keeps **DML < 10k** and **callouts < 10** per execution in tests (assert via counters from mocks).
- For chunking, verify quotes per request stay within your chosen threshold (e.g., 50–100).

---

## Manual / UAT Checklist (15–20 min)
- **Admin**: Set Named Credential; toggle `Persist_Latest_Ex_Rates__c`; set `Retention_Days__c = 1`.
- **Run Currency Sync** (scheduled or on demand): verify currencies inserted/deactivated.
- **If persist=true**: confirm rates exist for today; re-run once → no duplicates.
- **If persist=false**: open UI that reads rates → values display; no new `ExchangeRate__c` rows.
- **Quota/status**: hit an admin action that calls `/v1/status` and confirm remaining quotas display (if implemented).
- **Cleanup**: Manually create an old rate; run chain → row deleted.

---

## Coverage & Exit Criteria
- **85%+** coverage overall; **90%+** for service and queueable classes.
- All matrix cases green.
- No test relies on external network.
- Idempotency proven: same-day re-runs don’t create duplicates.
- Cleanup proven: only out-of-window rows deleted.

---

## CI Notes (optional now, easy later)
- Run tests on PR with a “mock-only” suite (no external deps).
- Surface a short test summary: pass/fail counts, code coverage, and timings.