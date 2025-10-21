# Jobs and Scheduling

## Scheduling Strategy
- Admin schedules CurrencySync as desired in Setup > Apex Classes > Schedule Apex
- CurrencySync always runs FetchCurrencies

Persist_Latest_Ex_Rates__c = true
FetchCurrencies > FetchLatestRates > DeleteOldRates
- FetchLatestRates runs from finish() of FetchCurrencies
- DeleteOldRates always runs after FetchLatestRates

Persist_Latest_Ex_Rates__c = false
- CurrencySync + FetchCurrencies still run on Admin-defined schedule
- Exchange rates are fetched on-demand from UI

## Implementation Notes
Queueable
- All jobs are run Queueably for POC. Can be easily converted to batch based on future needs.

Limit-Aware
- Jobs check DML/Callout/Timeout/Heap limits periodically during execution
- Jobs breaks processing and requeues as needed

Cleanup
- DeleteOldRates delegates to Batch interface if recordsToProcess > 10000

## CurrencySync
- Schedulable Apex Class.
- Orchestrates running FetchCurrencies + child jobs.
- No callouts or business logic.

## FetchCurrencies
- Calls 'v1/currencies'
- Upserts currency records
- Deactivates currencies no longer in use
- Conditional: runs FetchLatestRates based on org settings

## FetchLatestRates
- Precondition: Persist_Latest_Ex_Rates__c == TRUE
- Calls 'v1/latest'
- Performs a callout for each base currency to get all possible exchange rates
- Upserts exchange rates using Key__c for duplicate detection
- Runs DeleteOldRates always

## DeleteOldRates
- Precondition: FetchLatestRates runs (I.E. Persist_Latest_Ex_Rates__c == TRUE)
- Queries + deletes exchange rates that are outside the retention window
- Retention window is derived from Retention_Days__c setting (non-zero value required by Validation Rule)

## Notes
- Error mapping, auth, and rate-limit behavior defined in "Integrations.md"