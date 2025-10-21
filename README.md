

### Observability (for now)
- Log one record per external call and per job step to `Integration_Log__c`.
- Capture: endpoint, result (Success/Fail), httpStatus, durationMs, retryCount,
  rowsInserted/Updated/Deactivated (if any), quotaRemainingMinute/Month, requestId, timestamp,
  errorClass/errorMessage (truncated). No secrets or payloads.
- Minimal helper: `Log.info(...)` / `Log.error(...)` that upserts Integration_Log__c.
- Admin view (later): simple Lightning page showing last success times, remaining quota from /status,
  and the last 50 log entries. Not required for this submission.