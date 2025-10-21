# Data Model

## Outcomes
### What questions will the app answer?
1) Show all currencies in use today
- Provide a list of all currencies that are used in the world today

2) Show Current Exchange Rate
- Shows the current exchange rate between any two currencies

3) Show Historical Exchange Rate
- Shows the exchange rate between any two currencies on a specified historical date

### How is the data updated?
1) Scheduled Apex
- Configured via Apex Classes in Setup

2) Manual Refresh
- Triggered via the Admin Panel

3) ??? - Metadata Controls
- controls whether data is persisted, which data is persisted, and for how long

* research how frequently the API is updated or how often exchange rates are calculated

## Entities
### Currency__c
#### Custom Fields
1) Symbol__c
- Symbol of the currency in the Latin Alphabet
- Char limit: 50

2) Symbol_Native__c
- Local/native symbol of the currency
- Char limit: 80

3) Decimal_Digits__c
- Number of decimal digits this currency supports
- Length: 3

4) Rounding__c
- Rounding strategy this currency uses for an evenly split currency unit
- Length: 1

5) Code__c
- 3-letter code identifying this currency
- Unique (case insensitive) / External Id / Required

6) Name_Plural__c
- Plural name for this currency

7) Active__c
- Denotes whether this currency is currently used or historical

8) Currency_End_Date__c
- Date this currency stopped being used

### ExchangeRate__c
#### Custom Fields
1) Base_Currency__c
- The base currency used to determine an exchange rate
- Required
- Prevent deletion of parent record if child exists

2) Quote_Currency__c
- The quote currency used to determine an exchange rate
- Required
- Prevent deletion of parent record if child exists

3) Key__c
- Identifier for system use.
- Unique / Required
- (Base_Currency__c + '|' + Quote_Currency__c + '|' + Rate_Date__c)

3) Rate__c
- Exchange rate value
- Length: 9 / Decimals: 9

4) Rate_Date__c
- The calendar date that this was the exchange rate for.

### CurrencyAppConfig__mdt
#### Custom Fields
1) Persist_Latest_Ex_Rates__c
- Tells the system to persist the latest exchange rate in the database whenever the API is queried. Creates a row for each Base + Quote combination when fetching the latest data.

2) Retention_Days__c
- Number of days exchange rate records will be persisted in the database before an automated cleanup.

???
3) Use_on_Demand__c
- Bypasses the database check entirely and calls the API directly.

???
4) Allowed_Codes__c
- comma-separated list of codes to retrieve currency and exchange rate info for.

???
5) Show_Quota_In_Admin__c
- displays API usage and quota info on-demand in the Admin console by calling the API directly. No database interaction.

#### Rules
1) Require a non-zero value in Retention_Days__c when Persist_Latest_Ex_Rates__c == TRUE
AND(
    Persist_Latest_Ex_Rates__c == TRUE,
    OR(
        ISBLANK( Retention_Days__c ),
        Retention_Days__c = 0
    )
)

### ??? Job__c
- Test UI for error handling against AsyncApexJob and CronTrigger before building out Job__c. Might be worth stipulating for future development if I end up going standard object route.

## Key Queries
1) Get all currencies
[SELECT Id, Name, Code__c FROM Currency__c LIMIT 1000];

2) Get currency by Id
[SELECT ALL_FIELDS FROM Currency__c WHERE Id = :currencyId];

3) Get currency by Code
[SELECT ALL_FIELDS FROM Currency__c WHERE Code__c = :currencyCode];

4) Get currency by Name (contains)
String queryString = '%' + currencyName + '%';
[SELECT ALL_FIELDS FROM Currency__c WHERE Name LIKE :queryString];

## Invariants
- Currency codes are unique and not manually editable
- 

## Relationship Style (current choice)

ExchangeRate__c is connected to Currency__c by two lookup relationships. One lookup captures the "Base" Currency, the other captures the "Quote" currency. Both lookups are required and set to prevent the deletion of either parent Currency__c record if a child ExchangeRate__c exists.

- Prevents possibility of orphaned ExchangeRate__c records.
- An ExchangeRate__c record should never exists without both a Base_Currency__c and Quote_Currency__c.
- Provides developer control over ExchangeRate__c permissions and visibility.
- More flexible than Master-Detail for future changes.