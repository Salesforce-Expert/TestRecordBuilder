@isTest
public class TestRecordBuilder {
    // Cache for describe results and record type IDs
    private static Map<String, Schema.SObjectType> sObjectDescribeCache = new Map<String, Schema.SObjectType>();
    private static Map<String, Map<String, Id>> recordTypeCache = new Map<String, Map<String, Id>>();

    // State variables for fluent interface
    private List<SObject> records = new List<SObject>();
    private Map<String, Object> defaultValues = new Map<String, Object>();
    private Integer recordCount = 1;
    private String sObjectTypeName;

    // Inner class for managing callouts
    private Map<String, HttpResponse> calloutResponses = new Map<String, HttpResponse>();

    // Private Constructor to ensure proper usage via the factory method
    private TestRecordBuilder(String sObjectTypeName) {
        this.sObjectTypeName = sObjectTypeName;
    }

    // Factory method to initiate the builder
    public static TestRecordBuilder of(String sObjectTypeName) {
        return new TestRecordBuilder(sObjectTypeName);
    }

    // Set the number of records to create
    public TestRecordBuilder withRecordCount(Integer count) {
        this.recordCount = count;
        return this;
    }

    // Set default field values for records
    public TestRecordBuilder withDefaultValues(Map<String, Object> values) {
        this.defaultValues = values;
        return this;
    }

    // Set record-specific values
    public TestRecordBuilder withRecordSpecificValues(Integer index, Map<String, Object> values) {
        if (index >= 0 && index < records.size()) {
            setValues(records[index], values);
        }
        return this;
    }

    // Set the Record Type using Describe methods
    public TestRecordBuilder withRecordType(String recordTypeName) {
        Id recordTypeId = getRecordTypeId(sObjectTypeName, recordTypeName);
        if (recordTypeId != null) {
            defaultValues.put('RecordTypeId', recordTypeId);
        }
        return this;
    }

    // Add callout response configurations
    public TestRecordBuilder setCalloutResponse(String endpoint, Integer statusCode, String body) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setBody(body);
        calloutResponses.put(endpoint, response);
        return this;
    }

    // Builds and inserts records into the database
    public List<SObject> buildAndInsert() {
        buildRecords();
        insert records;
        return records;
    }

    // Builds records in memory without inserting
    public List<SObject> build() {
        buildRecords();
        return records;
    }

    // Helper method to create records with default and specific values
    private void buildRecords() {
        for (Integer i = 0; i < recordCount; i++) {
            SObject record = (SObject) getSObjectDescribe(sObjectTypeName).newSObject();
            setValues(record, defaultValues);
            records.add(record);
        }
    }

    // Helper method to set values on an SObject
    private void setValues(SObject record, Map<String, Object> values) {
        for (String field : values.keySet()) {
            record.put(field, values.get(field));
        }
    }

    // Retrieve SObjectType using cache and Describe methods
    private static Schema.SObjectType getSObjectDescribe(String sObjectTypeName) {
        if (!sObjectDescribeCache.containsKey(sObjectTypeName)) {
            sObjectDescribeCache.put(sObjectTypeName, Schema.getGlobalDescribe().get(sObjectTypeName));
        }
        return sObjectDescribeCache.get(sObjectTypeName);
    }

    // Retrieve Record Type ID using Describe
    private static Id getRecordTypeId(String sObjectTypeName, String recordTypeName) {
        if (!recordTypeCache.containsKey(sObjectTypeName)) {
            recordTypeCache.put(sObjectTypeName, new Map<String, Id>());
            Map<String, Schema.RecordTypeInfo> rtInfos = getSObjectDescribe(sObjectTypeName).getDescribe().getRecordTypeInfosByDeveloperName();
            for (String rtName : rtInfos.keySet()) {
                recordTypeCache.get(sObjectTypeName).put(rtName, rtInfos.get(rtName).getRecordTypeId());
            }
        }
        return recordTypeCache.get(sObjectTypeName).get(recordTypeName);
    }

    // Inner class to manage dynamic HTTP callouts
    public class DynamicMockHttpCallout implements HttpCalloutMock {
        private Map<String, HttpResponse> endpointResponses;

        public DynamicMockHttpCallout(Map<String, HttpResponse> endpointResponses) {
            this.endpointResponses = endpointResponses;
        }

        public HttpResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            if (endpointResponses.containsKey(endpoint)) {
                return endpointResponses.get(endpoint);
            } else {
                // Default 404 response if endpoint not configured
                HttpResponse defaultResponse = new HttpResponse();
                defaultResponse.setStatusCode(404);
                defaultResponse.setBody('Endpoint not configured in mock.');
                return defaultResponse;
            }
        }
    }

    // Configure callout mock with predefined responses
    public TestRecordBuilder configureCalloutMock() {
        Test.setMock(HttpCalloutMock.class, new DynamicMockHttpCallout(calloutResponses));
        return this;
    }
}
