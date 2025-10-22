public class FreeCurrencyApiResponses {

    public class StatusInfo {
        public String total;
        public String used;
        public String remaining;
    }
    public class StatusResponse {
        // Status response varies a bit by plan — keep generic for forward compatibility
        public String account_id;
        public Map<String, StatusInfo> quotas;
    }
    
    public class LatestResponse {
        public Map<String, Decimal> data;
        public String base_currency;
    }

    public class CurrencyInfo {
        public String name;
        public String symbol;
        public String symbol_native;
        public String decimal_digits;
        public String rounding;
        public String code;
        public String name_plural;
    }
    public class CurrenciesResponse {
        // e.g., data: { "USD": { name: "United States Dollar", symbol: "$" }, ... }
        public Map<String, CurrencyInfo> data;
    }

    public class HistoricalResponse {
        // e.g., data: { "2025-10-01": { "EUR": 0.94, "JPY": 160.1 }, ... }
        public Map<String, Map<String, Decimal>> data;
        public String base_currency;
    }
}