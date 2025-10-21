# Runbook

## Common Issues
- 401: Invalid key → Update Named Credential key; re-run CurrencySync.
- 422: Bad code/date → Fix Allowed_Codes__c or UI input; re-run.
- 429: Rate limit → Wait or reduce calls; rely on cached/persisted data.
- 5xx: Provider error → Re-run job (Queueable chain is idempotent).


# TODO: make sure Job__c made it into final implementation
## How to Verify Health
- Check last Job__c entries for /currencies and /latest within past 24h.
- Confirm rows added/updated and non-zero DurationMs.

## How to Re-run
- From Execute Anonymous (apex code) or the Admin Panel (ui button)
- If persistence on: it will chain to LatestRates and Cleanup automatically.

## Data Fix
- Delete duplicate rate rows where Key__c collides (shouldn’t happen; upsert protects).
- Re-run LatestRates for the affected date/base.