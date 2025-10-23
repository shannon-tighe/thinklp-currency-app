public with sharing class RateConverterController {

    // Lightweight DTO for initial data retrieval
    public class CurrencyCode {
        @AuraEnabled public String code { get; set; }
        @AuraEnabled public String name { get; set; }

        public CurrencyCode(String c, String n) {
            this.code = c;
            this.name = n;
        }
    }

    // Returns Name and Code__c for all active currencies.
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

    // DTO for conversion result.
    // Supports future extensibility without breaking existing UI contract.
    public class ConvertResult {
        @AuraEnabled public Decimal convertedAmount { get; set; }
        @AuraEnabled public Decimal rate { get; set; }
        @AuraEnabled public Date rateDate { get; set; }
        @AuraEnabled public String baseCode { get; set; }
        @AuraEnabled public String quoteCode { get; set; }

        public ConvertResult(Decimal convertedAmount, Decimal rate, Date rateDate, String baseCode, String quoteCode) {
            this.convertedAmount = convertedAmount;
            this.rate = rate;
            this.rateDate = rateDate;
            this.baseCode = baseCode;
            this.quoteCode = quoteCode;
        }
    }
    /**
     * Converts amount from Base to Quote currency
     * - If rateDate is null, uses the "latest" endpoint, otherwise, uses "historical" for that date.
     * - Minimizes API calls by checking database for existing records before calling API
     * - Returns all relevant info including rate and convertedAmount
     */
    @AuraEnabled
    public static ConvertResult convert(Decimal amount, String baseCode, String quoteCode, Date rateDate) {
        System.debug('Base Code ==> ' + baseCode);
        // Validate Required Parameters
        if (String.isBlank(baseCode) || String.isBlank(quoteCode)) {
            throw new AuraHandledException('Base and Quote currency codes are required.');
        }
        if (amount == null) {
            throw new AuraHandledException('Amount is required.');
        }

        // Check database for existing exchange rate, call API if not found
        // If no rate is found, default rate to 1 to return amount unchanged.
        RatesService service = new RatesService();
        Decimal rate = service.getRate(baseCode, quoteCode, rateDate);
        if(rate == null) {
            throw new AuraHandledException(
                'Apologies. No exchange rate found for ' + baseCode + ' to ' + quoteCode
                + (rateDate == null ? '' : ' on ' + rateDate)
                +'\nPlease try again later or contact your system administrator if the issue persists.'
            );
        }

        // Return DTO for easy handling and future extensability
        return new ConvertResult((rate * amount), rate, rateDate, baseCode, quoteCode);
    }
}