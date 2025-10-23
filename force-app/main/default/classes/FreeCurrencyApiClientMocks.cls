@isTest
public with sharing class FreeCurrencyApiClientMocks {

    // URL Paths using Named Credential
    private static final String STATUS_PATH     = 'callout:FreeCurrencyAPI/status';
    private static final String LATEST_PATH     = 'callout:FreeCurrencyAPI/latest';
    private static final String CURRENCIES_PATH = 'callout:FreeCurrencyAPI/currencies';
    private static final String HISTORICAL_PATH = 'callout:FreeCurrencyAPI/historical';

    // Set a date for a week ago and store in string
    public static final String dateString = String.valueOf(Date.today() - 7);

    /**
     * Mock for the /status endpoint
     * Tests can toggle error scenarios by including a Status code (400-5xx) under the "simulate" header.
     * Example: request.setHeader('simulate', 403);
     */
    public class StatusMock implements HttpCalloutMock {

        // Payload for successful 200 response
        String payload = '{' +
            '"quotas": {' +
            '   "month": {' +
            '       "total": 300,' +
            '       "used": 71,' +
            '       "remaining": 229' +
            '   }' +
            ' }' +
        '}';
        
        public HttpResponse respond(HttpRequest req) {
            // Ensure proper method and url path
            validateRequest(req);

            // Check headers to see if error should be simulated
            if (req.getHeader('simulate') == null) return get200();

            // Extract relevant header value and simulate errors
            String errorCode = req.getHeader('simulate');
            return getSimulatedError(errorCode);
        }

        private void validateRequest(HttpRequest req) {
            System.assertEquals('GET', req.getMethod(), 'Expected GET method');
            System.assert(req.getEndpoint().startsWith(STATUS_PATH), 'Unexpected endpoint');
        }

        private HttpResponse get200() {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(payload);
            return res;
        }
    }

    public class LatestMock implements HttpCalloutMock {

        // Payload for successful 200 response
        String payload = '{' +
            '"data": {' +
                '"EUR": 0.94,' +
                '"JPY": 160.12' +
            '},' +
            '"base_currency": "USD"'  +
        '}';

        public HttpResponse respond(HttpRequest req) {
            // Ensure proper method and url path
            validateRequest(req);

            // Check headers to see if error should be simulated
            if (req.getHeader('simulate') == null) return get200();

            // Extract relevant header value and simulate errors
            String errorCode = req.getHeader('simulate');
            return getSimulatedError(errorCode);
        }

        private void validateRequest(HttpRequest req) {
            System.assertEquals('GET', req.getMethod(), 'Expected GET method');
            System.assert(req.getEndpoint().startsWith(LATEST_PATH), 'Unexpected endpoint');
        }

        private HttpResponse get200() {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setHeader('X-RateLimit-Limit-Quota-Month', '300');
            res.setHeader('X-RateLimit-Remaining-Quota-Month', '229');
            res.setBody(payload);
            return res;
        }
    }

    public class CurrenciesMock implements HttpCalloutMock {

        // Payload for successful 200 response
        String payload = '{'+
            '"data": {' +
                '"USD": {' +
                    '"name": "United States Dollar",' +
                    '"symbol": "$",' +
                    '"symbol_native": "$",' +
                    '"decimal_digits": "2",' +
                    '"rounding": "0",' +
                    '"code": "USD",' +
                    '"name_plural": "US dollars"' +
                '},' +
                '"EUR": {' +
                    '"name": "Euro",' +
                    '"symbol": "€",' +
                    '"symbol_native": "€",' +
                    '"decimal_digits": "2",' +
                    '"rounding": "0",' +
                    '"code": "EUR",' +
                    '"name_plural": "euros"' +
                '}' +
            '}' +
        '}';

        
        public HttpResponse respond(HttpRequest req) {
            // Ensure proper method and url path
            validateRequest(req);

            // Check headers to see if error should be simulated
            if (req.getHeader('simulate') == null) return get200();

            // Extract relevant header value and simulate errors
            String errorCode = req.getHeader('simulate');
            return getSimulatedError(errorCode);
        }

        private void validateRequest(HttpRequest req) {
            System.assertEquals('GET', req.getMethod(), 'Expected GET method');
            System.assert(req.getEndpoint().startsWith(CURRENCIES_PATH), 'Unexpected endpoint');
        }

        private HttpResponse get200() {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setHeader('X-RateLimit-Limit-Quota-Month', '300');
            res.setHeader('X-RateLimit-Remaining-Quota-Month', '229');
            res.setBody(payload);
            return res;
        }
    }

    public class HistoricalMock implements HttpCalloutMock {

        // Payload for successful 200 response
        String payload = '{' +
                '"data": {' +
                    '"' + dateString + '": {' +
                        '"EUR": 0.94,' +
                        '"JPY": 160.12' +
                    '}' +
                '},' +
                '"base_currency": "USD"' +
            '}';
        
        public HttpResponse respond(HttpRequest req) {
            // Ensure proper method and url path
            validateRequest(req);

            // Check headers to see if error should be simulated
            if (req.getHeader('simulate') == null) return get200();

            // Extract relevant header value and simulate errors
            String errorCode = req.getHeader('simulate');
            return getSimulatedError(errorCode);
        }

        private void validateRequest(HttpRequest req) {
            System.assertEquals('GET', req.getMethod(), 'Expected GET method');
            System.assert(req.getEndpoint().startsWith(HISTORICAL_PATH), 'Unexpected endpoint');
        }

        private HttpResponse get200() {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setHeader('X-RateLimit-Limit-Quota-Month', '300');
            res.setHeader('X-RateLimit-Remaining-Quota-Month', '229');
            res.setBody(payload);
            return res;
        }
    }

    public static HttpResponse getSimulatedError(String errorCode) {
        switch on errorCode {
            when '401' { return get401(); }
            when '403' { return get403(); }
            when '404' { return get404(); }
            when '422' { return get422(); }
            when '429' { return get429(); }
            when '500' { return get500(); }
            when else {
                throw new FreeCurrencyApiClientMocksException('Invalid simulate error code: ' + errorCode);
            }
        }
    }

    private static HttpResponse get401() {
        return baseJson(401, '{"error":"Invalid authentication credentials"}');
    }
    private static HttpResponse get403() {
        return baseJson(403, '{"error":"Not allowed on current plan"}');
    }
    private static HttpResponse get404() {
        return baseJson(404, '{"error":"Endpoint not found"}');
    }
    private static HttpResponse get422() {
        return baseJson(422, '{"error":"Validation error"}');
    }
    private static HttpResponse get429() {
        return baseJson(429, '{"error":"Rate limit exceeded"}');
    }
    private static HttpResponse get500() {
        return baseJson(500, '{"error":"Upstream failure"}');
    }

    private static HttpResponse baseJson(Integer status, String body) {
        HttpResponse r = new HttpResponse();
        r.setStatusCode(status);
        r.setHeader('Content-Type','application/json');
        if (body != null) {
            r.setBody(body);
        }
        
        return r;
    }

    private class FreeCurrencyApiClientMocksException extends Exception {}
}