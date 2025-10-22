public inherited sharing class FreeCurrencyApiClient {
    
    // Endpoints
    private static final String STATUS_PATH     = '/status';
    private static final String LATEST_PATH     = '/latest';
    private static final String CURRENCIES_PATH = '/currencies';
    private static final String HISTORICAL_PATH = '/historical';

    /**
     * Public methods for each supported URL path
     */
    /** GET /status */
    public static FreeCurrencyApiResponses.StatusResponse getStatus() {
        HttpResponse res = get(STATUS_PATH, null);
        return (FreeCurrencyApiResponses.StatusResponse) JSON.deserialize(res.getBody(), FreeCurrencyApiResponses.StatusResponse.class);
    }
    // Method to return total available API calls by combining "grace" and "monthly" quota data
    public static Integer getRemainingApiCalls() {
        FreeCurrencyApiResponses.StatusResponse status = getStatus();

        Integer graceQuota = 0;
        Integer monthlyQuota = 0;

        if(status.quotas.containsKey('grace')) {
            String val = status.quotas.get('grace')?.remaining;
            graceQuota = val == null ? 0 : Integer.valueOf(val);
        }
        if(status.quotas.containsKey('month')) {
            String val = status.quotas.get('month')?.remaining;
            monthlyQuota = val == null ? 0 : Integer.valueOf(val);
        }
        
        return graceQuota + monthlyQuota;
    }

    /**
     * GET /latest
     * @param baseCurrency (optional) e.g., "USD"
     * @param currenciesCsv (optional) comma-separated e.g., "EUR,JPY,CAD". By default all will be shown
     */
    public static FreeCurrencyApiResponses.LatestResponse getLatest(String baseCurrency, String currenciesCsv) {
        Map<String,String> params = new Map<String,String>();
        if (!String.isBlank(baseCurrency)) params.put('base_currency', baseCurrency);
        if (!String.isBlank(currenciesCsv)) params.put('currencies', currenciesCsv);
        HttpResponse res = get(LATEST_PATH, params);
        return (FreeCurrencyApiResponses.LatestResponse) JSON.deserialize(res.getBody(), FreeCurrencyApiResponses.LatestResponse.class);
    }

    /**
     * GET /currencies 
     * @param baseCurrency (optional) e.g., "USD"
     */
    public static FreeCurrencyApiResponses.CurrenciesResponse getCurrencies() {
        HttpResponse res = get(CURRENCIES_PATH, null);
        return (FreeCurrencyApiResponses.CurrenciesResponse) JSON.deserialize(res.getBody(), FreeCurrencyApiResponses.CurrenciesResponse.class);
    }

    /**
     * GET /historical
     * @param date ISO date "YYYY-MM-DD" (required)
     * @param baseCurrency (optional)
     * @param currenciesCsv (optional)
     */
    public static FreeCurrencyApiResponses.HistoricalResponse getHistorical(String rateDate, String baseCurrency, String currenciesCsv) {
        Map<String,String> params = new Map<String,String>();
        if (!String.isBlank(rateDate))          params.put('date', rateDate);
        if (!String.isBlank(baseCurrency))  params.put('base_currency', baseCurrency);
        if (!String.isBlank(currenciesCsv)) params.put('currencies', currenciesCsv);
        HttpResponse res = get(HISTORICAL_PATH, params);
        return (FreeCurrencyApiResponses.HistoricalResponse) JSON.deserialize(res.getBody(), FreeCurrencyApiResponses.HistoricalResponse.class);
    }

    /**
     * Private methods
     */
    static HttpResponse get(String path, Map<String, String> params) {
        // Validate params
        path = path.removeStart('/').removeEnd('/');

        // Create request
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:FreeCurrencyAPI/' + path + getParamString(params));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        System.debug('Request ==> ' + req);

        // Send request and return response
        Http h = new Http();
        HttpResponse resp = h.send(req);
        validateResponse(resp);
        return resp;
    }

    static String getParamString(Map<String, String> params) {
        // Return empty string if no params
        if (params == null || params.isEmpty()) {
            return '';
        }

        // Build param string
        List<String> paramList = new List<String>();
        for(String key : params.keySet()) {
            if (params.get(key) == null) {
                continue;
            }

            String pair = EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8');

            paramList.add(pair);
        }

        return '?' + String.join(paramList, '&');
    }

    static void validateResponse(HttpResponse resp) {
        Integer status = resp.getStatusCode();

        // Do nothing if request was successful
        if(status != null && status >= 200 && status < 300) {
            return;
        }

        // Construct error message and throw typed exception if unsuccessful
        String msg = '';

        switch on status {
            when 401 {
                msg = 'Your API credentials are invalid or expired. Please check your credentials and try again.';
            }
            when 422 {
                msg = 'There was a validation error with your input parameter(s). Please check your input and try again.';
            }
            when 429 {
                msg = 'You are out of available API calls. Please try again in a few minutes.';
            }
            when else {
                msg = 'An unknown error occurred. Please try again later.';
            }
        }

        msg += ' If the issue persists, contact your administrator with the details below.\nApi Error Message: ' + resp.getBody();
        throw new FreeCurrencyApiException(msg);
    }

    public class FreeCurrencyApiException extends Exception {}
}