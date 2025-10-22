@IsTest
private class FreeCurrencyApiClientTest {

    // ------------------------------------------------------------
    // Minimal router-style HttpCalloutMock for these tests only
    // ------------------------------------------------------------
    private class RouterMock implements HttpCalloutMock {
        private Map<String, HttpResponse> byPath = new Map<String, HttpResponse>();

        RouterMock add(String pathFragment, Integer status, String body) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(status);
            if (body != null) r.setBody(body);
            byPath.put(pathFragment, r);
            return this;
        }

        public HTTPResponse respond(HTTPRequest req) {
            String ep = req.getEndpoint();
            // Choose the first registered fragment contained in the endpoint
            for (String key : byPath.keySet()) {
                if (ep != null && ep.contains(key)) return byPath.get(key);
            }
            // Default 404 for unregistered paths to surface missing fixtures
            HttpResponse nf = new HttpResponse();
            nf.setStatusCode(404);
            nf.setBody('Mock: no response registered for endpoint: ' + ep);
            return nf;
        }
    }

    // ------------------------------------------------------------
    // Sample payloads matching FreeCurrencyApiResponses.cls
    // ------------------------------------------------------------
    private static String statusPayload() {
        // Your StatusResponse has: data (Map<String,Object>) and base_currency (optional)
        return '{"data":{"plan":"free","quota":{"month":{"limit":50000,"remaining":49990},"minute":{"limit":60,"remaining":57}}},"base_currency":"USD"}';
    }

    private static String latestPayload() {
        // LatestResponse: data (Map<String,Decimal>), base_currency
        return '{"data":{"EUR":0.94,"JPY":160.12},"base_currency":"USD"}';
    }

    private static String currenciesPayload() {
        // CurrenciesResponse: data of code -> CurrencyInfo (your model includes several optional fields)
        return '{"data":{"USD":{"name":"United States Dollar","symbol":"$","code":"USD","name_plural":"US dollars"},"EUR":{"name":"Euro","symbol":"€","code":"EUR","name_plural":"euros"}}}';
    }

    private static String historicalPayload() {
        // HistoricalResponse: data of date -> (code -> Decimal), base_currency
        return '{"data":{"2025-10-01":{"EUR":0.93,"JPY":159.01},"2025-10-02":{"EUR":0.94,"JPY":160.12}},"base_currency":"USD"}';
    }

    // ------------------------------------------------------------
    // Happy-path tests
    // ------------------------------------------------------------

    @IsTest
    static void getStatus_success() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/status', 200, statusPayload()));

        Test.startTest();
        FreeCurrencyApiResponses.StatusResponse res = FreeCurrencyApiClient.getStatus();
        Test.stopTest();

        System.assertNotEquals(null, res, 'DTO should not be null');
        System.assertNotEquals(null, res.data, 'data should not be null');
        System.assertEquals('free', (String)res.data.get('plan'));
        // base_currency is optional; present in our fixture:
        System.assertEquals('USD', res.base_currency);
    }

    @IsTest
    static void getLatest_success() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/latest', 200, latestPayload()));

        Test.startTest();
        FreeCurrencyApiResponses.LatestResponse res =
            FreeCurrencyApiClient.getLatest('USD', 'EUR,JPY');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals('USD', res.base_currency);
        System.assertEquals(0.94, res.data.get('EUR'));
        System.assertEquals(160.12, res.data.get('JPY'));
    }

    @IsTest
    static void getCurrencies_success() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/currencies', 200, currenciesPayload()));

        Test.startTest();
        FreeCurrencyApiResponses.CurrenciesResponse res = FreeCurrencyApiClient.getCurrencies();
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertNotEquals(null, res.data);
        System.assertEquals('United States Dollar', res.data.get('USD').name);
        System.assertEquals('€', res.data.get('EUR').symbol);
        // Your model also includes optional fields like code/name_plural; ensure they map when present
        System.assertEquals('USD', res.data.get('USD').code);
        System.assertEquals('euros', res.data.get('EUR').name_plural);
    }

    @IsTest
    static void getHistorical_success() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/historical', 200, historicalPayload()));

        Test.startTest();
        FreeCurrencyApiResponses.HistoricalResponse res =
            FreeCurrencyApiClient.getHistorical('2025-10-02', 'USD', 'EUR,JPY');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals('USD', res.base_currency);
        System.assertEquals(0.94, res.data.get('2025-10-02').get('EUR'));
        System.assertEquals(160.12, res.data.get('2025-10-02').get('JPY'));
    }

    // ------------------------------------------------------------
    // Error-path tests
    // (Your client maps codes to friendly text and appends the API message body.
    //  We assert on the unified FreeCurrencyApiException and that the message
    //  includes the upstream API error snippet.)
    // ------------------------------------------------------------

    @IsTest
    static void error_401_unauthorized() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/latest', 401, '{"message":"Invalid API key"}'));

        try {
            Test.startTest();
            FreeCurrencyApiClient.getLatest('USD', 'EUR');
            System.assert(false, 'Expected FreeCurrencyApiException');
        } catch (FreeCurrencyApiClient.FreeCurrencyApiException e) {
            System.assert(e.getMessage().contains('Invalid API key'),
                'Message should include upstream API error body');
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void error_403_forbidden_plan() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/historical', 403, '{"message":"Not allowed on current plan"}'));

        try {
            Test.startTest();
            FreeCurrencyApiClient.getHistorical('2025-10-02', 'USD', 'EUR');
            System.assert(false);
        } catch (FreeCurrencyApiClient.FreeCurrencyApiException e) {
            System.assert(e.getMessage().contains('Not allowed on current plan'));
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void error_404_not_found() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/currencies', 404, '{"message":"Endpoint not found"}'));

        try {
            Test.startTest();
            FreeCurrencyApiClient.getCurrencies();
            System.assert(false);
        } catch (FreeCurrencyApiClient.FreeCurrencyApiException e) {
            System.assert(e.getMessage().contains('Endpoint not found'));
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void error_422_validation() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/latest', 422, '{"message":"Invalid base_currency"}'));

        try {
            Test.startTest();
            FreeCurrencyApiClient.getLatest('ZZZ', 'EUR');
            System.assert(false);
        } catch (FreeCurrencyApiClient.FreeCurrencyApiException e) {
            System.assert(e.getMessage().contains('Invalid base_currency'));
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void error_429_rate_limit() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/latest', 429, '{"message":"Too Many Requests"}'));

        try {
            Test.startTest();
            FreeCurrencyApiClient.getLatest('USD', 'EUR');
            System.assert(false);
        } catch (FreeCurrencyApiClient.FreeCurrencyApiException e) {
            // Your client crafts a friendly message and appends the API body; assert the body portion
            System.assert(e.getMessage().contains('Too Many Requests'));
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void error_500_server() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock().add('/status', 500, '{"message":"Upstream failure"}'));

        try {
            Test.startTest();
            FreeCurrencyApiClient.getStatus();
            System.assert(false);
        } catch (FreeCurrencyApiClient.FreeCurrencyApiException e) {
            System.assert(e.getMessage().contains('Upstream failure'));
        } finally {
            Test.stopTest();
        }
    }
}