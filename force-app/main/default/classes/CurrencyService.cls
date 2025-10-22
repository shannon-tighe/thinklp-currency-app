public with sharing class CurrencyService implements Queueable, Database.AllowsCallouts {
    
    public CurrencyService() {}

    public void execute(QueueableContext context) {
        sync();

        // Schedule next job if Retention_Days__c is configured for the "settings" custom MD record
        RatesService service = new RatesService();
        if(service.isRetentionDaysConfigured()) {
            System.enqueueJob(new RatesService());
        }
    }

    public void sync() {
        // Check Usage Limits
        FreeCurrencyApiResponses.StatusResponse status = FreeCurrencyApiClient.getStatus();
        System.debug('Remaining calls: ' + FreeCurrencyApiClient.getRemainingApiCalls());
        if(FreeCurrencyApiClient.getRemainingApiCalls() < 1) {
            return;
        }

        // Perform Callout
        FreeCurrencyApiResponses.CurrenciesResponse currencies = FreeCurrencyApiClient.getCurrencies();
        System.debug('Currencies Response:\n' + currencies);

        // Stage records for upsert
        List<Currency__c> currenciesToUpsert = new List<Currency__c>();
        for(FreeCurrencyApiResponses.CurrencyInfo curr : currencies.data.values()) {
            // Safely coerce data types
            Decimal decimalDigits = curr.decimal_digits == null ? null : Decimal.valueOf(curr.decimal_digits);
            Decimal rounding = curr.rounding == null ? null : Decimal.valueOf(curr.rounding);

            currenciesToUpsert.add(
                new Currency__c(
                    Name = curr.name,
                    Symbol__c = curr.symbol,
                    Symbol_Native__c = curr.symbol_native,
                    Decimal_Digits__c = decimalDigits,
                    Rounding__c = rounding,
                    Code__c = curr.code,
                    Name_Plural__c = curr.name_plural,
                    Active__c = true
                )
            );
        }

        if(currenciesToUpsert.isEmpty()) {
            return;
        }

        // Upsert Existing Currencies
        System.debug(currenciesToUpsert.size() + ' currencies to upsert\n' + currenciesToUpsert);
        Database.upsert(currenciesToUpsert, Currency__c.Fields.Code__c, false);

        // Deactivate historical currencies
        Set<Id> existingCurrencyIds = new Set<Id>();
        for(Currency__c curr : currenciesToUpsert) {
            existingCurrencyIds.add(curr.Id);
        }

        List<Currency__c> currenciesToDeactivate = new List<Currency__c>();
        for(Currency__c curr : [SELECT Active__c FROM Currency__c WHERE Id NOT IN :existingCurrencyIds AND Active__c = TRUE]) {
            curr.Active__c = false;
            currenciesToDeactivate.add(curr);
        }

        if(!currenciesToDeactivate.isEmpty()) {
            update currenciesToDeactivate;
        }
    }
}