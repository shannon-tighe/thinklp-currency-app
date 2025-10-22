public with sharing class CurrencyServiceScheduler implements Schedulable {

    public CurrencyServiceScheduler() {}

    public void execute(SchedulableContext context) {
        CurrencyService service = new CurrencyService();
        System.enqueueJob(service);
    }
}