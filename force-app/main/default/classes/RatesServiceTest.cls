@IsTest
private class RatesServiceTest {

    private static Currency_App_Config__mdt settings;

    // ---- tiny helpers ----
    private static void addCurrency(String code, String name) {
        insert new Currency__c(Name = name, Code__c = code, Active__c = true);
    }
    private static void setConfig(Boolean persist, Integer retentionDays) {
        settings = new Currency_App_Config__mdt(
            DeveloperName = 'Settings',
            MasterLabel   = 'Settings',
            Persist_Latest_Ex_Rates__c = persist,
            Retention_Days__c          = retentionDays
        );
    }

    // 1) Happy path: latest rate + persistence enabled
    @IsTest
    static void getRate_latest_minimal() {
        // Arrange
        addCurrency('USD','US Dollar');
        addCurrency('EUR','Euro');
        setConfig(true, 30);
        Test.setMock(HttpCalloutMock.class, new FreeCurrencyApiClientMocks.LatestMock());

        // Act
        Test.startTest();
        Decimal rate = new RatesService().getRate('USD','EUR', null);
        Test.stopTest();

        // Assert (just enough)
        System.assertEquals(0.94, rate);
        System.assertEquals(1,
            [SELECT COUNT() FROM Exchange_Rate__c WHERE Base_Currency__r.Code__c='USD' AND Quote_Currency__r.Code__c='EUR'
             AND Rate_Date__c = :Date.today()],
            'Should persist one latest row');
    }

    // 2) Cleanup: deletes rows older than retention window
    @IsTest
    static void deleteOldRates_minimal() {
        // Arrange
        addCurrency('USD','US Dollar');
        addCurrency('EUR','Euro');
        setConfig(true, 7); // keep a week

        // old row (10 days ago)
        Exchange_Rate__c oldRow = new Exchange_Rate__c(
            Name='USD to EUR',
            Base_Currency__c=[SELECT Id FROM Currency__c WHERE Code__c='USD' LIMIT 1].Id,
            Quote_Currency__c=[SELECT Id FROM Currency__c WHERE Code__c='EUR' LIMIT 1].Id,
            Key__c='USD|EUR|' + String.valueOf(Date.today().addDays(-10)),
            Rate__c=0.9,
            Rate_Date__c=Date.today().addDays(-10)
        );
        insert oldRow;
        Test.setCreatedDate(oldRow.Id, DateTime.now().addDays(-10));

        // Act
        new RatesService().deleteOldRates();

        // Assert
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Exchange_Rate__c],
            'Old rows should be deleted when beyond retention window'
        );
    }
}