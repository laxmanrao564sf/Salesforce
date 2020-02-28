/*
    BatchCreateARSnapshots sc1 = new BatchCreateARSnapshots(null);
    Database.executebatch(sc1);
*/
global class BatchCreateARSnapshots implements Database.Batchable<sObject>, Schedulable {
    
    String query;
    global list<Aging__c> aging;
    
    global BatchCreateARSnapshots(String sQuery) {
        if(sQuery != null) {
            query = sQuery;
        } else {
            query = 'Select blng__Balance__c, Overdue_Days__c From blng__Invoice__c WHERE blng__InvoiceStatus__c =\'Posted\' AND blng__Balance__c > 0 ORDER By blng__Account__c';
        }
        
        aging = [SELECT Id, (SELECT ARSnapshotFieldName__c, Name, Number__c, StartDay__c, EndDay__c FROM AgingBuckets__r ORDER By Number__c) FROM Aging__c];
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<blng__Invoice__c> scope) {
        List<ARSnapshot__c> arSnapShotsToCreate = new List<ARSnapshot__c>();
        List<blng__Invoice__c> invoices = scope;
        
        for(blng__Invoice__c invoice : invoices) {
            ARSnapshot__c arSnapShot = new ARSnapshot__c();
            AgingBucketHanlder.caclulateARBuckets(invoice, arSnapShot, aging[0].AgingBuckets__r);  
            arSnapShotsToCreate.add(arSnapShot);  
        }
        
        insert arSnapShotsToCreate;
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }

    global void execute(SchedulableContext sc) {
        // schedule the apex class only if their is not existing job running
        boolean isBatchJobRunning = Billing_BatchUtility.isBatchJobRunning('Billing_BatchCreateOrders');

        // check if there is any open place to schedule the class
        boolean isJobQueueFull = Billing_BatchUtility.isBatchJobQueueFull();
        
        if(isBatchJobRunning == Billing_BatchUtility.BOOLEAN_FALSE){
            if (isJobQueueFull == Billing_BatchUtility.BOOLEAN_FALSE) {
                Database.executeBatch(this, 200);
            } else {
                //schedule this same schedulable class again in 30 mins
                BatchCreateARSnapshots sc1 = new BatchCreateARSnapshots(null);
                Datetime dt = Datetime.now().addMinutes(30);  // i.e. 30 mins
                String timeForScheduler = dt.format('s m H d M \'?\' yyyy');
                Id schedId = System.Schedule('BatchCreateARSnapshots'+timeForScheduler,timeForScheduler,sc1);
            }
        }   
    }
}