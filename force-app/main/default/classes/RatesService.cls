public with sharing class RatesService implements Queueable, Database.AllowsCallouts {

    Currency_App_Config__mdt settings;

    public RatesService() {
        this.settings = getSettings();
    }

    Currency_App_Config__mdt getSettings() {
        // Query settings
        List<Currency_App_Config__mdt> settingsList = [
                SELECT Retention_Days__c, Persist_Latest_Ex_Rates__c
                FROM Currency_App_Config__mdt
                WHERE DeveloperName = 'Settings' LIMIT 1
            ];

        return settingsList.isEmpty() ? null : settingsList[0];
    }

    public Boolean isRetentionDaysConfigured() {
        return settings != null && settings.Retention_Days__c > 0;
    }

    public Boolean isPersistenceEnabled() {
        return settings != null && settings.Persist_Latest_Ex_Rates__c;
    }

    public void execute(QueueableContext context) {
        deleteOldRates();
    }

    public void deleteOldRates() {
        // Exit early if settings aren't configured
        if(!isRetentionDaysConfigured()) {
            System.debug('Retention_Days__c is not configured. Exiting cleanup job.');
            return;
        }

        // Create a date for filtering based on retention days
        Date retentionDate = Date.today() - settings?.Retention_Days__c.intValue();

        // Count rows before performing query + dml
        Integer rowCount = [SELECT COUNT() FROM Exchange_Rate__c WHERE CreatedDate < :retentionDate];

        // Exit if there
        if(rowCount == 0) {
            System.debug('No records to delete. Exiting cleanup job.');
            return;
        }

        // Only delete records if limits permit - otherwise delegate to the appropriate interface
        if(rowCount < (.95 * Limits.getLimitDmlRows())) {
            delete [SELECT Id FROM Exchange_Rate__c WHERE CreatedDate < :retentionDate];
        } else if(rowCount > 9500) {
            System.enqueueJob(
                new RatesService()
            );
        }
    }

    // Attempt to query an existing record from the DB. Calls API if no record found.
    public Decimal getRate(String baseCode, String quoteCode, Date rateDate) {
        // If rateDate is null or today, uses the "latest" endpoint. Otherwise uses "historical".
        // Sending today's date to "/historical" can result in validation error upon Date >> Datetime conversion:
        // Converted date value is compared against a generted now() UTC value.
        if(rateDate == null || rateDate == Date.today()) rateDate = null;
        
        // Normalize case and validate the comparison
        // Rate is always 1 if base and quote are the same
        String baseISO = baseCode.trim().toUpperCase();
        String quoteISO   = quoteCode.trim().toUpperCase();
        if (baseISO == quoteISO) {
            return 1;
        }

        // Attempt to query an existing record from the DB
        List<Exchange_Rate__c> existingRate = [
                SELECT Rate__c
                FROM Exchange_Rate__c
                WHERE Base_Currency__r.Code__c = :baseISO
                AND Quote_Currency__r.Code__c = :quoteISO
                AND Rate_Date__c = :rateDate
                LIMIT 1
            ];
        // If found, return the existing rate
        if(!existingRate.isEmpty()) return existingRate[0].Rate__c;

        // Fetch rates from the appropriate endpoint if not in DB
        Map<String, Decimal> rateMap;
        if(rateDate == null) {
            FreeCurrencyApiResponses.LatestResponse res = FreeCurrencyApiClient.getLatest(baseISO, null);
            rateMap = res?.data;
        } else {
            String dateString = String.valueOf(rateDate);
            FreeCurrencyApiResponses.HistoricalResponse res = FreeCurrencyApiClient.getHistorical(dateString, baseISO, null);
            rateMap = res?.data.get(dateString);
        }
        System.debug('Rate Map:\n' + rateMap);

        // Exit early if no data was found.
        if(rateMap == null || rateMap.isEmpty()) {
            System.debug('No data retrieved, exiting early.');
            return null;
        }

        // Pass to RatesService to handle data persistence
        persistRates(baseISO, rateMap, rateDate);
        
        // Return just the rate
        return rateMap.get(quoteISO);
    }

    // Upserts new rates if Persist_Latest_Ex_Rates__c == TRUE
    void persistRates(String baseISO, Map<String, Decimal> rateMap, Date rateDate) {
        // Exit early if settings aren't configured
        if(!isPersistenceEnabled()) {
            System.debug('Persistence is not enabled. Exiting cleanup job.');
            return;
        }

        // Map ISO Code to Currency Id to prep Exchange_Rate__c records for upsert
        Map<String, Id> codesToIds = getCodeMap();

        // Make sure rateDate has a value for stringifying
        rateDate = rateDate == null ? Date.today() : rateDate;

        // Extract rates from response and upsert
        List<Exchange_Rate__c> ratesToUpsert = new List<Exchange_Rate__c>();
        for(String quoteCode : rateMap.keySet()) {
            // Skip 1:1 comparison
            if(quoteCode == baseISO) continue;
            // Skip creation if corresonding base or quote currency record is missing
            if(!codesToIds.containsKey(baseISO) || !codesToIds.containsKey(quoteCode)) continue;

            // Populate new exchange rate record
            Exchange_Rate__c rateRec = new Exchange_Rate__c(
                Name = baseISO + ' to ' + quoteCode,
                Base_Currency__c = codesToIds.get(baseISO),
                Quote_Currency__c = codesToIds.get(quoteCode),
                Key__c = baseISO + '|' + quoteCode + '|' + String.valueOf(rateDate),
                Rate__c = rateMap.get(quoteCode),
                Rate_Date__c = rateDate
            );

            ratesToUpsert.add(rateRec);
        }

        // Upsert new records and return rate for this comparison - allow partial success
        if(!ratesToUpsert.isEmpty()) Database.upsert(ratesToUpsert, Exchange_Rate__c.Fields.Key__c, false);
    }

    // Cache results for repeated queries
    private static Map<String, Id> cachedCodeMap;
    static Map<String, Id> getCodeMap() {
        // Return cached version if one already exists in the transaction
        if(cachedCodeMap <> null) return cachedCodeMap;

        cachedCodeMap = new Map<String, Id>();

        // Get all active currencies
        List<Currency__c> currencies = [
            SELECT Id, Code__c
            FROM Currency__c
            WHERE Active__c = TRUE
        ];
        System.debug(currencies.size() + ' currencies.');

        // Map currency code to record id
        for(Currency__c curr : currencies) {
            cachedCodeMap.put(curr.Code__c, curr.Id);
        }

        return cachedCodeMap;
    }

    private class RatesServiceException extends Exception {}
}