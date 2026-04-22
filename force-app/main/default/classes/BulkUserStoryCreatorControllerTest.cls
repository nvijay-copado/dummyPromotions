@IsTest
private class BulkUserStoryCreatorControllerTest {

    @TestSetup
    static void setupData() {
        // 0. Grant Copado license to bypass validation rules
        TestUtilities.setup();

        System.runAs(TestUtilities.getRunAsUser()) {
            // 1. Create Environments
            copado__Environment__c envDev = new copado__Environment__c(Name = 'Dev');
            copado__Environment__c envUat = new copado__Environment__c(Name = 'UAT');
            insert new List<copado__Environment__c>{ envDev, envUat };
            
            // 2. Create Pipeline
            copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c(
                Name = 'Test Pipeline',
                copado__Active__c = true
            );
            insert pipeline;
            
            // 3. Create Pipeline Step
            copado__Deployment_Flow_Step__c step = new copado__Deployment_Flow_Step__c(
                copado__Deployment_Flow__c = pipeline.Id,
                copado__Source_Environment__c = envDev.Id,
                copado__Destination_Environment__c = envUat.Id
            );
            insert step;
            
            // 4. Create Project
            copado__Project__c project = new copado__Project__c(
                Name = 'Test Project',
                copado__Deployment_Flow__c = pipeline.Id
            );
            insert project;
            
            // 5. Create Release
            copado__Release__c release = new copado__Release__c(
                Name = 'Test Release',
                copado__Project__c = project.Id,
                copado__Version__c = '1.0'
            );
            insert release;
            
            // 6. Create User Story with specific Title to mock a Batch creation
            copado__User_Story__c us = new copado__User_Story__c(
                copado__User_Story_Title__c = 'Batch TEST_BATCH_ID Created - US 0001',
                copado__Project__c = project.Id,
                copado__Release__c = release.Id,
                copado__Environment__c = envDev.Id,
                copado__Status__c = 'Approved'
            );
            insert us;
            
            // 7. Create Metadata
            copado__User_Story_Metadata__c usm = new copado__User_Story_Metadata__c(
                copado__User_Story__c = us.Id,
                copado__Metadata_API_Name__c = 'TestClass',
                copado__Type__c = 'ApexClass',
                copado__Action__c = 'Add'
            );
            insert usm;

             List<copado__Org__c> orgs = TestUtilities.createOrgCredentials(2, TestUtilities.getRunAsUser().UserName, new List<copado__Environment__c>{ envDev, envUat });
            
            // 8. Create Promotion
            copado__Promotion__c promo = new copado__Promotion__c(
                copado__Project__c = project.Id,
                copado__Release__c = release.Id,
                copado__Source_Environment__c = envDev.Id,
                copado__Destination_Environment__c = envUat.Id,
                copado__Status__c = 'Completed'
            );
            insert promo;
            
            // 9. Create Promoted User Story link
            copado__Promoted_User_Story__c pus = new copado__Promoted_User_Story__c(
                copado__User_Story__c = us.Id,
                copado__Promotion__c = promo.Id
            );
            insert pus;
        }
    }

    @IsTest
    static void testGetLookups() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__Deployment_Flow__c pipeline = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
            copado__Project__c project = [SELECT Id FROM copado__Project__c LIMIT 1];
            
            Test.startTest();
            
            // Test Pipelines
            List<BulkUserStoryCreatorController.LookupOption> pipelines = BulkUserStoryCreatorController.getPipelines();
            Assert.areEqual(1, pipelines.size(), 'Should return 1 active pipeline');
            
            // Test Projects
            List<BulkUserStoryCreatorController.LookupOption> projects = BulkUserStoryCreatorController.getProjectsByPipeline(pipeline.Id);
            Assert.areEqual(1, projects.size(), 'Should return 1 project tied to the pipeline');
            List<BulkUserStoryCreatorController.LookupOption> noProjects = BulkUserStoryCreatorController.getProjectsByPipeline(null);
            Assert.isTrue(noProjects.isEmpty(), 'Should return empty list if pipelineId is null');
            
            // Test Releases
            List<BulkUserStoryCreatorController.LookupOption> releases = BulkUserStoryCreatorController.getReleasesByProject(project.Id);
            Assert.areEqual(2, releases.size(), 'Should return 2 options: Null selector and 1 release');
            List<BulkUserStoryCreatorController.LookupOption> noReleases = BulkUserStoryCreatorController.getReleasesByProject(null);
            Assert.isTrue(noReleases.isEmpty(), 'Should return empty list if projectId is null');
            
            // Test Record Types
            List<BulkUserStoryCreatorController.LookupOption> recordTypes = BulkUserStoryCreatorController.getUserStoryRecordTypes();
            Assert.isNotNull(recordTypes, 'Record types list should not be null');
            
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testGetPipelineDetails() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__Deployment_Flow__c pipeline = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
            
            Test.startTest();
            BulkUserStoryCreatorController.PipelineDetails details = BulkUserStoryCreatorController.getPipelineDetails(pipeline.Id);
            BulkUserStoryCreatorController.PipelineDetails nullDetails = BulkUserStoryCreatorController.getPipelineDetails(null);
            Test.stopTest();
            
            Assert.isNull(nullDetails, 'Should return null when ID is null');
            Assert.isNotNull(details, 'Should return pipeline details');
            Assert.areEqual('Test Pipeline', details.pipelineName, 'Pipeline name should match');
            Assert.areEqual(2, details.totalEnvironments, 'Should have 2 unique environments in steps');
            Assert.isNotNull(details.firstEnvironmentId, 'First environment should be set');
            Assert.isNotNull(details.finalEnvironmentId, 'Final environment should be set');
        }
    }

    @IsTest
    static void testValidateConfiguration() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__Deployment_Flow__c pipeline = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
            copado__Project__c project = [SELECT Id FROM copado__Project__c LIMIT 1];
            
            String validJson = '{' +
                '"pipelineId": "' + pipeline.Id + '",' +
                '"projectId": "' + project.Id + '",' +
                '"userStoryRecordTypeId": "' + Schema.SObjectType.copado__User_Story__c.getRecordTypeInfosByDeveloperName().get('User_Story').getRecordTypeId() + '",' +
                '"totalUserStories": 100,' +
                '"userStoriesPerBatch": 20,' +
                '"metadataPerUserStory": 5' +
            '}';
            
            String invalidJsonMissingFields = '{' +
                '"totalUserStories": 0,' +
                '"userStoriesPerBatch": -1,' +
                '"metadataPerUserStory": -5' +
            '}';
            
            Test.startTest();
            BulkUserStoryCreatorController.ValidationResult validResult = BulkUserStoryCreatorController.validateConfiguration(validJson);
            BulkUserStoryCreatorController.ValidationResult invalidResult = BulkUserStoryCreatorController.validateConfiguration(invalidJsonMissingFields);
            BulkUserStoryCreatorController.ValidationResult syntaxErrorResult = BulkUserStoryCreatorController.validateConfiguration('NOT_JSON');
            Test.stopTest();
            
            // Valid checks
            Assert.isTrue(validResult.isValid, 'Configuration should be valid');
            Assert.areEqual(0, validResult.errors.size(), 'Should have no errors');
            Assert.areEqual(5, validResult.estimatedBatches, 'Should calculate 5 batches for 100 items at 20 per batch');
            
            // Invalid checks
            Assert.isFalse(invalidResult.isValid, 'Configuration should be invalid');
            Assert.isTrue(invalidResult.errors.size() >= 5, 'Should flag all missing and invalid negative/zero inputs');
            
            // Syntax error checks
            Assert.isFalse(syntaxErrorResult.isValid, 'Invalid JSON should return invalid');
            Assert.isTrue(syntaxErrorResult.errors[0].contains('Error parsing configuration'), 'Should catch JSON exception');
        }
    }

    @IsTest
    static void testBatchExecutionMethods() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__Deployment_Flow__c pipeline = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
            copado__Project__c project = [SELECT Id FROM copado__Project__c LIMIT 1];
            copado__Environment__c env = [SELECT Id FROM copado__Environment__c WHERE Name = 'Dev' LIMIT 1];
            
            String configJson = '{' +
                '"pipelineId": "' + pipeline.Id + '",' +
                '"projectId": "' + project.Id + '",' +
                '"userStoryRecordTypeId": "' + Schema.SObjectType.copado__User_Story__c.getRecordTypeInfosByDeveloperName().get('User_Story').getRecordTypeId() + '",' +
                '"totalUserStories": 2,' +
                '"userStoriesPerBatch": 2,' +
                '"metadataPerUserStory": 1,' +
                '"selectedEnvironmentId": "' + env.Id + '",' +
                '"executionMode": "READY_TO_PROMOTE"' +
            '}';
            
            Test.startTest();
            // 1. Test Start Batch
            BulkUserStoryCreatorController.BatchStartResult startResult = BulkUserStoryCreatorController.startBatch(configJson);
            
            // 2. Test Get Batch Status
            BulkUserStoryCreatorController.BatchJobStatus statusResult;
            if (startResult.success) {
                statusResult = BulkUserStoryCreatorController.getBatchStatus(startResult.batchId);
            }
            Test.stopTest();
            
            Assert.isTrue(startResult.success, 'Batch should start successfully');
            Assert.isNotNull(startResult.batchId, 'Should return a valid Batch ID');
            Assert.isNotNull(statusResult, 'Should retrieve batch status details');
            Assert.areEqual(startResult.batchId, statusResult.batchId, 'Status ID should match the started batch ID');
            
            // Handle failure scenario
            BulkUserStoryCreatorController.BatchStartResult failedStart = BulkUserStoryCreatorController.startBatch('{}');
            Assert.isFalse(failedStart.success, 'Should fail to start with empty config');
        }
    }

    @IsTest
    static void testDataRetrievalAndSummaries() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__Project__c project = [SELECT Id FROM copado__Project__c LIMIT 1];
            copado__Release__c release = [SELECT Id FROM copado__Release__c LIMIT 1];
            copado__User_Story__c us = [SELECT Id FROM copado__User_Story__c LIMIT 1];
            
            String configJson = '{' +
                '"projectId": "' + project.Id + '",' +
                '"releaseId": "' + release.Id + '"' +
            '}';
            
            Test.startTest();
            
            // 1. Get User Stories created by Batch
            BulkUserStoryCreatorController.UserStoryListResult listResult = BulkUserStoryCreatorController.getUserStoriesCreatedByBatch(
                configJson, 'TEST_BATCH_ID', 10, 0
            );
            
            // 2. Metadata count
            BulkUserStoryCreatorController.MetadataCountResult metaCount = BulkUserStoryCreatorController.getMetadataCountForUserStory(us.Id);
            BulkUserStoryCreatorController.MetadataCountResult nullMetaCount = BulkUserStoryCreatorController.getMetadataCountForUserStory(null);
            
            // 3. Batch Summary
            BulkUserStoryCreatorController.BatchSummary summary = BulkUserStoryCreatorController.getBatchCreationSummary(configJson);
            BulkUserStoryCreatorController.BatchSummary nullSummary = BulkUserStoryCreatorController.getBatchCreationSummary(null);
            
            Test.stopTest();
            
            // Assert User Story List
            Assert.isTrue(listResult.success, 'Query should be successful');
            Assert.areEqual(1, listResult.totalCount, 'Should find 1 matching User Story');
            Assert.areEqual('Approved', listResult.userStories[0].status, 'Status property should map correctly');
            Assert.isNotNull(listResult.userStories[0].latestPromotionId, 'Promotion lookup should map successfully');
            
            // Assert Metadata Count
            Assert.isTrue(metaCount.success, 'Count operation should be successful');
            Assert.areEqual(1, metaCount.count, 'Should find 1 metadata item attached to the US');
            Assert.areEqual(0, nullMetaCount.count, 'Null ID should return 0 count safely');
            
            // Assert Summary
            Assert.isTrue(summary.success, 'Summary aggregation should succeed');
            Assert.areEqual(1, summary.totalUserStories, 'Should summarize 1 User Story in total');
            Assert.areEqual(1, summary.totalMetadata, 'Should summarize 1 Metadata record in total');
            Assert.isTrue(summary.statusBreakdown.containsKey('Approved'), 'Breakdown map should contain "Approved" status');
        }
    }
}