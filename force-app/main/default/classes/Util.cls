public class Util {
    
    public static void run() {
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint('callout:FreeCurrencyAPI/v1/status');
        req.setMethod('GET');
        
        Http h = new Http();
        HttpResponse resp = h.send(req);
        
        System.debug(resp);
        System.debug(resp.getBody());
    }
}