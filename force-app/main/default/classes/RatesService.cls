public with sharing class RatesService implements Queueable {

    public RatesService() {}

    public void execute(QueueableContext context) {
        deleteOldRates();
    }

    // TODO: implement Queueable and Batch handlers for cleanup job
    // TODO: add lightweight static cache for rates
    // TODO: Chat is angry about my try/catch syntax - spend time undersatnding why...

    // Attempt to query an existing record from the DB. Calls API if no record found.
    public static Decimal getRate(String baseISO, String quoteISO, Date rateDate) {
        // Attempt to query an existing record from the DB
        List<Exchange_Rate__c> existingRate = [
                SELECT Rate__c
                FROM Exchange_Rate__c
                WHERE Base_Currency__r.Code__c = :baseISO
                AND Quote_Currency__r.Code__c = :quoteISO
                AND Rate_Date__c = :rateDate
                LIMIT 1
            ];
        if(!existingRate.isEmpty()) return existingRate[0].Rate__c;

        // Fetch rates from the API if not in DB
        // Always use the historical endpoint - it accepts today's date
        String dateString = String.valueOf(rateDate);
        FreeCurrencyApiResponses.HistoricalResponse res = FreeCurrencyApiClient.getHistorical(dateString, baseISO, null);
        if(res == null || res.data == null) {
            System.debug('No data retrieved, exiting early.');
            return null;
        }

        Map<String, Decimal> rateMap = res.data.get(dateString);
        System.debug('Response:\n' + res);
        System.debug('Rate Map:\n' + rateMap);

        // Pass to RatesService to handle data persistence
        RatesService.persistRates(baseISO, rateMap, rateDate);
        
        // Return just the rate
        return rateMap.get(quoteISO);
    }

    public static void persistRates(String baseISO, Map<String, Decimal> rateMap, Date rateDate) {
        // Query settings
        List<Currency_App_Config__mdt> settingsList = [
                SELECT Persist_Latest_Ex_Rates__c 
                FROM Currency_App_Config__mdt
                WHERE DeveloperName = 'Settings' LIMIT 1
            ];
            
        // Exit early if settings aren't configured
        if(settingsList.isEmpty() || !settingsList[0].Persist_Latest_Ex_Rates__c) {
            System.debug('Persistence is not enabled. Exiting job.');
            return;
        }

        // Map ISO Code to Currency Id to prep Exchange_Rate__c records for upsert
        Map<String, Id> codesToIds = getCodeMap();

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

        // Upsert new records and return rate for this comparison
        if(!ratesToUpsert.isEmpty()) upsert ratesToUpsert Key__c;
    }

    // Cache results for repeated queries
    private static Map<String, Id> cachedCodeMap;
    static Map<String, Id> getCodeMap() {
        // Return cached version if one already exists in the transaction
        if(cachedCodeMap <> null) return cachedCodeMap;

        cachedCodeMap = new Map<String, Id>();

        // Get all active currencies
        List<Currency__c> currencies = [
            SELECT Code__c, Name, Symbol__c, Active__c
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

    public void deleteOldRates() {
        // Query settings
        List<Currency_App_Config__mdt> settingsList = [
                SELECT Retention_Days__c
                FROM Currency_App_Config__mdt
                WHERE DeveloperName = 'Settings' LIMIT 1
            ];
            
        // Exit early if settings aren't configured
        if(settingsList.isEmpty() || !(settingsList[0].Retention_Days__c > 0)) {
            System.debug('Retention_Days__c is not configured. Exiting cleanup job.');
            return;
        }

        // Extract settings object
        Currency_App_Config__mdt settings = settingsList[0];

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
        } else{
            // ...
        }
    }
}