@IsTest
public class FreeCurrencyApiHttpMock implements HttpCalloutMock {

    // Map of path → response. Store as either pure path (e.g., "/v1/latest")
    // or full path with query (e.g., "/v1/latest?base_currency=USD&currencies=EUR%2CJPY")
    private final Map<String, HttpResponse> byPath = new Map<String, HttpResponse>();

    // Capture the last request for assertions in tests.
    public static HttpRequest lastRequest { get; private set; }

    public FreeCurrencyApiHttpMock() {}

    /** Register a mock response for a given path (with or without query string). */
    public FreeCurrencyApiHttpMock add(String path, Integer status, String body, Map<String,String> headers) {
        HttpResponse r = new HttpResponse();
        r.setStatusCode(status);
        if (body != null) r.setBody(body);
        if (headers != null) {
            for (String h : headers.keySet()) r.setHeader(h, headers.get(h));
        }
        byPath.put(path, r);
        return this;
    }

    public HTTPResponse respond(HTTPRequest req) {
        lastRequest = req;

        // Endpoint looks like "callout:FreeCurrencyAPI/v1/latest?..." (depends on NC)
        // Normalize to path portion starting at "/v1/" (or just the tail after the host)
        String endpoint = req.getEndpoint();
        String norm = normalizePath(endpoint);

        // Try exact match first (with query), then without query
        if (byPath.containsKey(norm)) return byPath.get(norm);

        String onlyPath = stripQuery(norm);
        if (byPath.containsKey(onlyPath)) return byPath.get(onlyPath);

        // Not found: return a 404 so tests surface missing fixtures clearly
        HttpResponse notFound = new HttpResponse();
        notFound.setStatusCode(404);
        notFound.setBody('Mock path not found: ' + norm);
        return notFound;
    }

    // ----------------- Public helpers for tests -----------------

    /** Returns the normalized full path (including query) of the last request, or null. */
    public static String fullPathOfLastRequest() {
        if (lastRequest == null) return null;
        return normalizePath(lastRequest.getEndpoint());
    }

    /** Returns just the path portion (no query) of the last request, e.g., "/v1/latest". */
    public static String pathOfLastRequest() {
        String full = fullPathOfLastRequest();
        return full == null ? null : stripQuery(full);
    }

    /** Returns the raw query string of the last request (no leading '?'), or empty string. */
    public static String queryOfLastRequest() {
        String full = fullPathOfLastRequest();
        if (full == null) return null;
        Integer q = full.indexOf('?');
        return q == -1 ? '' : full.substring(q + 1);
    }

    // ----------------- Private utilities -----------------

    private static String normalizePath(String endpoint) {
        if (String.isBlank(endpoint)) return endpoint;

        // If the Named Credential URL includes /v1 we want the substring beginning with "/v1".
        // Otherwise, try to find the first "/" after the scheme/host or NC alias and return that tail.
        Integer i = endpoint.indexOf('/v1/');
        if (i >= 0) return endpoint.substring(i);

        // Fallback: find first slash after the NC alias "callout:Name"
        Integer colon = endpoint.indexOf(':');
        Integer firstSlash = endpoint.indexOf('/', (colon == -1 ? 0 : colon + 1));
        if (firstSlash >= 0) return endpoint.substring(firstSlash);

        // Last resort: return as-is
        return endpoint;
    }

    private static String stripQuery(String fullPath) {
        if (String.isBlank(fullPath)) return fullPath;
        Integer q = fullPath.indexOf('?');
        return q == -1 ? fullPath : fullPath.substring(0, q);
    }
}