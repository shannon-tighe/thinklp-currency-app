public with sharing class RateConverterController {

    public class CurrencyCode {
        @AuraEnabled public String code { get; set; }
        @AuraEnabled public String name { get; set; }

        public CurrencyCode(String c, String n) {
            this.code = c;
            this.name = n;
        }
    }
    /**
     * Returns supported currency ISO codes with currency names from your org.
     * Backed by your Currency__c table synced by CurrencyService.
     */
    @AuraEnabled(cacheable=true)
    public static List<CurrencyCode> getSupportedCurrencyCodes() {
        // Get 
        List<Currency__c> currencies = [
            SELECT Name, Code__c
            FROM Currency__c
            WHERE Name != null AND Active__c = TRUE
            ORDER BY Name
        ];
        List<CurrencyCode> codes = new List<CurrencyCode>();
        for (Currency__c c : currencies) {
            codes.add(new CurrencyCode(c.Code__c, c.Name));
        }
        return codes;
    }

    /**
     * Convert amount from -> to.
     * - If rateDate is null, uses the "latest" endpoint.
     * - Otherwise, uses "historical" for that date.
     * Minimizes API calls by fetching only FROM and TO rates with base=USD,
     * then deriving A->B as usd[B]/usd[A].
     */
    @AuraEnabled
    public static Decimal convert(Decimal amount, String baseCode, String quoteCode, Date rateDate) {
        System.debug('Base Code ==> ' + baseCode);
        // Validate Required Parameters
        if (String.isBlank(baseCode) || String.isBlank(quoteCode)) {
            throw new AuraHandledException('Base and Quote currency codes are required.');
        }
        // TODO: should amount be required? I'd like to provide a simple option to view exchange rate.
        if (amount == null) {
            throw new AuraHandledException('Amount is required.');
        }

        // Default rate date to today
        rateDate = rateDate ?? Date.today();
        
        // Normalize case and validate the comparison
        String baseISO = baseCode.trim().toUpperCase();
        String quoteISO   = quoteCode.trim().toUpperCase();
        if (baseISO == quoteISO) {
            return amount;
        }

        // Check database for existing exchange rate, call API if not found
        // If no rate is found, default rate to 1 to return amount unchanged.
        Decimal rate = RatesService.getRate(baseISO, quoteISO, rateDate) ?? 1;
        System.debug('Rate ==> ' + rate);

        return rate * amount;
    }
}