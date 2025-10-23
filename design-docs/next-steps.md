# Next Steps

?? This indicates a next step that seems logical to dev but would require review/approval from Product.
   Notes are included for each item.

## Dynamically Updated UI ??
- ?? changes UX and could consume additional API calls that clients may not wish to.
- make updates dynamically re-run convert() to populate new values.
- Option to make a two step process where we dynamically check the DB immediately. If not found, surface a message and require a User button click to reduce API calls.

## Add Jest Tests for LWC
- Add tests for rateConverter, ran out of time during POC build.

## Flush Out FreeCurrencyApiClient Mocks and Test
- make sure all headers and body messages returned for each error code are 100% accurate and complete
- add specific handling for input validation errors
- implement factory pattern for Mock and Test to expand tested cases with minimal redundancy

## Add Batch Path for Cleanup Job
- currently RatesService.deleteOldRates() checks count of records to delete and either proceeds in the current transaction or queues a new one. Would be ideal to delegate to Batch if n > 10000 (unlikely, but future-proof).

## Convert Custom Metadata to Custom Settings ??
- ?? dependent on whether this app is meant to be packaged.
- Custom settings would enable configuring User and Profile specific defaults but is less package-friendly.

## Move Queries to Query Layer and Add Caching
- Keep queries grouped by object in their own selector class and provide an option to cache query results using static props.
- Keeps service logic clean

## Build out an "Admin Panel" LWC ??
- ?? dependent on desired future state and investment
- Provides ability to trigger a resync without needing perms to run Apex
- View usage and remaining quota data