# Next Steps

## Dynamically Updated UI
- would need alignment with product and the business to determine whether this is desired based on API consumption and UX.
- make updates dynamically re-run convert() to populate new values.
- Option to make a two step process where we dynamically check the DB immediately. If not found, surface a message and require a User button click to reduce API calls.

## Add Batch Path for Cleanup Job
- currently RatesService.deleteOldRates() checks count of records to delete and either proceeds in the current transaction or queues a new one. Would be ideal to delegate to Batch if n > 10000 (unlikely, but future-proof).

## Convert Custom Metadata to Custom Settings
- Dependent on whether this app is meant to be packaged.
- Custom settings would enable configuring User and Profile specific defaults but is less package-friendly.

## Move Queries to Query Layer and Add Caching
- Keep queries grouped by object in their own selector class and provide an option to cache query results using static props.
- Keeps service logic clean