# Integration

## Endpoints
GET /v1/currencies
- returns all supported currencies
- inserts any new currencies and deactivates any that are no longer supported

GET /v1/latest
- returns daily latest exchange rates
- rates are updated EOD daily

GET /v1/historical
- single-day historical rates
- 
 (requires date=YYYY-MM-DD)

GET /v1/status
- returns account usage and remaining quota
- calls do not count against account quota

## Auth Structure
- All callouts are made in Apex using the following auth components

Named Credential
- 'https://api.freecurrencyapi.com'

Header
- 'apikey: ' + secureApiKey

## Auth + Rate Limit Handling
- All requests check API availaility via 'v1/status' before performing request
- Any errors follow the error handling bahvior detailed below

## HTTP behavior
- Only GET reqeusts

## Error Codes
401
- Inavlid/expired credentials.

422
- Validation (input) error

429
- Monthly limit hit

403, 404, 500
- Fatal error

## Error Handling
- Notify admin/log error.
- If one-off request from UI, surface error to end User
- Do not retry.