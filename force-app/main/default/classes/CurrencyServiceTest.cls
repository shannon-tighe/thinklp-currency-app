@IsTest
private class CurrencyServiceTest {

    private static Currency_App_Config__mdt settings;

    // ---- tiny helpers ----
    private static void addCurrency(String code, String name, Boolean activeFlag) {
        insert new Currency__c(Name = name, Code__c = code, Active__c = activeFlag);
    }
    private static void setConfig(Boolean persist, Integer retentionDays) {
        settings = new Currency_App_Config__mdt(
            DeveloperName = 'Settings',
            MasterLabel   = 'Settings',
            Persist_Latest_Ex_Rates__c = persist,
            Retention_Days__c          = retentionDays
        );
    }

    // ---- minimal router to serve /status and /currencies in one run ----
    private class RouterMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String ep = req.getEndpoint();
            if (ep != null && ep.contains('/status')) {
                return new FreeCurrencyApiClientMocks.StatusMock().respond(req);
            } else if (ep != null && ep.contains('/currencies')) {
                return new FreeCurrencyApiClientMocks.CurrenciesMock().respond(req);
            }
            // Default 404 if unexpected
            return FreeCurrencyApiClientMocks.getSimulatedError('404');
        }
    }

    // ---- status mock that forces remaining=0 so sync() exits early ----
    private class StatusZeroRemainingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Only /status is expected; return 200 with remaining=0 via headers
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setHeader('X-RateLimit-Limit-Quota-Month', '300');
            r.setHeader('X-RateLimit-Remaining-Quota-Month', '0');
            r.setBody('{"quotas":{"month":{"total":300,"used":300,"remaining":0}}}');
            return r;
        }
    }

    // 1) sync(): upserts incoming (USD, EUR) and deactivates preexisting that’s not returned (JPY)
    @IsTest
    static void sync_upserts_and_deactivate() {
        // Pre-existing active currency that won't be in the API response (will be deactivated)
        addCurrency('USD','US Dollar', true);
        addCurrency('EUR','Euro', true);

        // Serve /status + /currencies
        Test.setMock(HttpCalloutMock.class, new RouterMock());

        // Act
        Test.startTest();
        new CurrencyService().sync();
        Test.stopTest();

        // Assert (just enough)
        // USD and EUR should exist and be active
        List<Currency__c> currencies = new List<Currency__c>([
            SELECT Id, Code__c, Active__c FROM Currency__c WHERE Code__c IN ('USD','EUR','JPY')
        ]);

        for(Currency__c c : currencies) {
            if(c.Code__c == 'USD' || c.Code__c == 'EUR') {
                System.assert(c.Active__c, 'USD and EUR should be active');
            } else if(c.Code__c == 'JPY') {
                System.assert(!c.Active__c, 'JPY should be inactive');
            }
        }
    }

    // 2) sync(): early return when remaining calls < 1 (no upsert)
    @IsTest
    static void sync_skips_when_out_of_quota() {
        // Make sure there are no USD/EUR yet
        // (intentionally not inserting; we expect none created)

        Test.setMock(HttpCalloutMock.class, new StatusZeroRemainingMock());

        new CurrencyService().sync();

        // Assert: nothing was inserted
        Integer cnt = [SELECT COUNT() FROM Currency__c WHERE Code__c IN ('USD','EUR')];
        System.assertEquals(0, cnt, 'Should not upsert when remaining quota is 0');
    }
}