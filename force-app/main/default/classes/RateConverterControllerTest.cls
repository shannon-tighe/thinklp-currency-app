@IsTest
private class RateConverterControllerTest {

    @IsTest
    static void getSupportedCurrencyCodes_returnsActiveCurrencies() {
        // Arrange
        insert new Currency__c(Name='Euro', Code__c='EUR', Active__c=true);
        insert new Currency__c(Name='US Dollar', Code__c='USD', Active__c=true);
        insert new Currency__c(Name='Japanese Yen', Code__c='JPY', Active__c=false); // should be excluded

        // Act
        Test.startTest();
        List<RateConverterController.CurrencyCode> results = RateConverterController.getSupportedCurrencyCodes();
        Test.stopTest();
        
        // Assert
        System.assertEquals(2, results.size(), 'Should return only active currencies');
        
        Boolean hasEuro = false;
        Boolean hasUSD = false;
        for(RateConverterController.CurrencyCode code : results) {
            if(code.code == 'EUR') hasEuro = true;
            if(code.code == 'USD') hasUSD = true;
        }
        System.assert(hasEuro, 'Expected Euro in results.');
        System.assert(hasUSD, 'Expected USD in results.');
    }

    @IsTest
    static void convert_returnsExpectedResult() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new FreeCurrencyApiClientMocks.LatestMock());
        Decimal amount = 1;
        String baseCode = 'USD';
        String quoteCode = 'USD';
        Date rateDate = null;

        Decimal finalAmount = 100;
        Decimal expectedConverted = 1;

        // Act
        Test.startTest();
        RateConverterController.ConvertResult result = RateConverterController.convert(amount, baseCode, quoteCode, rateDate);
        Test.stopTest();

        // Assert
        System.assertEquals(expectedConverted, result.convertedAmount, 'Converted amount should match rate * amount');
        System.assertEquals('USD', result.baseCode);
        System.assertEquals('USD', result.quoteCode);
    }
    @IsTest
    static void convert_throwsWhenMissingFields() {
        // Missing codes
        try {
            RateConverterController.convert(10, null, 'EUR', null);
            System.assert(false, 'Expected AuraHandledException for missing codes');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Script-thrown exception'), 'Unexpected message: ' + e.getMessage());
        }

        // Missing amount
        try {
            RateConverterController.convert(null, 'USD', 'EUR', null);
            System.assert(false, 'Expected AuraHandledException for missing amount');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Script-thrown exception'));
        }
    }
}