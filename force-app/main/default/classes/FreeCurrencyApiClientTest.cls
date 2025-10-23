@IsTest
private class FreeCurrencyApiClientTest {

    // ---- Happy paths -------------------------------------------------------

    @IsTest
    static void status_ok() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new FreeCurrencyApiClientMocks.StatusMock());

        String totalCalls = '300';
        String usedCalls = '71';
        String remainingCalls = '229';

        // Act
        Test.startTest();
        FreeCurrencyApiResponses.StatusResponse res = FreeCurrencyApiClient.getStatus();
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, res, 'Status response should not be null');
        System.assertEquals(totalCalls, res.quotas.get('month').total,   'Total quota mismatch');
        System.assertEquals(usedCalls,  res.quotas.get('month').used,    'Used quota mismatch');
        System.assertEquals(remainingCalls, res.quotas.get('month').remaining, 'Remaining quota mismatch');

        // If your client exposes this convenience accessor, validate it too.
        Integer remaining = FreeCurrencyApiClient.getRemainingApiCalls();
        System.assertEquals(Integer.valueOf(remainingCalls), remaining, 'Remaining calls should reflect /status payload');
    }

    @IsTest
    static void currencies_ok() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new FreeCurrencyApiClientMocks.CurrenciesMock());

        // Act
        Test.startTest();
        FreeCurrencyApiResponses.CurrenciesResponse res = FreeCurrencyApiClient.getCurrencies();
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, res, 'Currencies response should not be null');
        System.assert(res.data.containsKey('USD'), 'Expected USD in currencies');
        System.assert(res.data.containsKey('EUR'), 'Expected EUR in currencies');

        FreeCurrencyApiResponses.CurrencyInfo usd = res.data.get('USD');
        System.assertEquals('United States Dollar', usd.name);
        System.assertEquals('$', usd.symbol);
        // Your DTO may coerce these to Decimal/Integer; adjust if needed.
        System.assertEquals('2', String.valueOf(usd.decimal_digits));
        System.assertEquals('0', String.valueOf(usd.rounding));
    }

    @IsTest
    static void latest_ok() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new FreeCurrencyApiClientMocks.LatestMock());

        // Act
        // Adjust method name/signature if yours differs (e.g., getLatestRates(), latest(), etc.)
        Test.startTest();
        FreeCurrencyApiResponses.LatestResponse res = FreeCurrencyApiClient.getLatest('USD', null);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, res, 'Latest response should not be null');
        System.assertEquals('USD', res.base_currency, 'Base currency mismatch');
        System.assert(res.data.containsKey('EUR'), 'EUR missing from latest data');
        System.assertEquals(0.94, res.data.get('EUR'), 'Unexpected EUR rate');
    }

    @IsTest
    static void historical_ok() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new FreeCurrencyApiClientMocks.HistoricalMock());
        String dateString = FreeCurrencyApiClientMocks.dateString;

        // Act
        // If your method requires a Date, pass Date.newInstance(2025,10,2) or similar; 
        // if it’s parameterless, keep as-is.
        Test.startTest();
        FreeCurrencyApiResponses.HistoricalResponse res = FreeCurrencyApiClient.getHistorical(
            dateString,
            'USD',
            null
        );
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, res, 'Historical response should not be null');
        System.assertEquals('USD', res.base_currency, 'Base currency mismatch');
        System.debug('Date String; ' + dateString);
        System.debug('Historical data:\n' + res.data);
        System.assert(res.data.containsKey(dateString), 'Expected date key missing');
        Map<String, Decimal> day = res.data.get(dateString);
        System.assertEquals(0.94, day.get('EUR'), 'Unexpected EUR historical rate');
    }

    // ---------------------------
    // Unhappy-paths via handlers in FreeCurrencyApiClientMocks (get401/get403/...)
    // ---------------------------

    @IsTest
    static void status_401() {
        // Use error helper from your mocks (line ~191+)
        Test.setMock(HttpCalloutMock.class, new ErrorMock('/status', '401'));
        Boolean threw = false;
        try {
            FreeCurrencyApiClient.getStatus();
        } catch (Exception e) {
            threw = true;
            System.assert(e.getMessage().contains('401') || e.getMessage().contains('Invalid authentication'),
                'Should surface a 401 authentication error');
        }
        System.assert(threw, 'Client should throw on 401 from /status');
    }

    @IsTest
    static void currencies_403() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock('/currencies', '403'));
        Boolean threw = false;
        try {
            FreeCurrencyApiClient.getCurrencies();
        } catch (Exception e) {
            threw = true;
            System.assert(e.getMessage().contains('403') || e.getMessage().contains('Not allowed'),
                'Should surface a 403 plan/permission error');
        }
        System.assert(threw, 'Client should throw on 403 from /currencies');
    }

    @IsTest
    static void latest_429() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock('/latest', '429'));
        Boolean threw = false;

        try {
            FreeCurrencyApiClient.getLatest('USD', null);
        } catch (Exception e) {
            threw = true;
            System.assert(e.getMessage().contains('429') || e.getMessage().contains('Rate limit'),
                'Should surface a 429 rate limit error');
        }
        System.assert(threw, 'Client should throw on 429 from /latest');
    }

    @IsTest
    static void historical_422() {
        // Example: validation error (e.g., malformed date); we just assert the client surfaces it.
        Test.setMock(HttpCalloutMock.class, new ErrorMock('/historical', '422'));
        Boolean threw = false;
        try {
            // Pass any date; mock will force 422 regardless.
            FreeCurrencyApiClient.getHistorical(FreeCurrencyApiClientMocks.dateString, 'USD', null);
        } catch (Exception e) {
            threw = true;
            System.assert(
                e.getMessage().contains('422') || e.getMessage().contains('Validation'),
                'Should surface a 422 validation error'
            );
        }
        System.assert(threw, 'Client should throw on 422 from /historical');
    }

    @IsTest
    static void historical_500() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock('/historical', '500'));
        Boolean threw = false;
        try {
            FreeCurrencyApiClient.getHistorical(FreeCurrencyApiClientMocks.dateString, 'USD', null);
        } catch (Exception e) {
            threw = true;
            System.assert(
                e.getMessage().contains('500') || e.getMessage().contains('Upstream'),
                'Should surface a 500 upstream failure'
            );
        }
        System.assert(threw, 'Client should throw on 500 from /historical');
    }

    // ---------------------------
    // Minimal test-local mock that RETURNS your centralized error payloads
    // (so we’re using the handlers defined in FreeCurrencyApiClientMocks)
    // ---------------------------
    private class ErrorMock implements HttpCalloutMock {
        private final String expectedPathFragment;
        private final String code;

        ErrorMock(String expectedPathFragment, String code) {
            this.expectedPathFragment = expectedPathFragment;
            this.code = code;
        }

        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint() != null && req.getEndpoint().contains(expectedPathFragment),
                'Unexpected endpoint. Was: ' + req.getEndpoint() + ' expected to contain ' + expectedPathFragment);
            // Use your handlers (e.g., get401/get403/get429...) via the switch wrapper
            return FreeCurrencyApiClientMocks.getSimulatedError(code);
        }
    }
}