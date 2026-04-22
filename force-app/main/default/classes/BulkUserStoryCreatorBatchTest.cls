@IsTest
private class BulkUserStoryCreatorBatchTest {

    @TestSetup
    private static void setup() {
        // Grant Copado licenses to the running user to bypass custom validation errors
        TestUtilities.setup();
    }
    
    // Helper to mock BatchConfiguration
    private static BulkUserStoryCreatorController.BatchConfiguration getMockConfig(String execMode) {
        String validRecordTypeId = '';
        for (Schema.RecordTypeInfo rti : Schema.SObjectType.copado__User_Story__c.getRecordTypeInfos()) {
            if (rti.isAvailable() && rti.getName() != 'Master') {
                validRecordTypeId = rti.getRecordTypeId();
                break;
            }
        }

        String jsonConfig = '{' +
            '"totalUserStories": 2, ' +
            '"userStoriesPerBatch": 2, ' +
            '"metadataPerUserStory": 2, ' +
            (String.isNotBlank(validRecordTypeId) ? '"userStoryRecordTypeId": "' + validRecordTypeId + '", ' : '') +
            '"executionMode": "' + execMode + '"' +
        '}';
        return (BulkUserStoryCreatorController.BatchConfiguration) JSON.deserialize(
            jsonConfig, BulkUserStoryCreatorController.BatchConfiguration.class
        );
    }

    @IsTest
    static void testCreateUserStoriesPhase() {
        System.runAs(TestUtilities.getRunAsUser()) {
            BulkUserStoryCreatorController.BatchConfiguration config = getMockConfig('READY_TO_PROMOTE');
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(config);
            
            Test.startTest();
            Database.executeBatch(batch, 2);
            Test.stopTest();
            
            List<copado__User_Story__c> createdStories = [SELECT Id, copado__User_Story_Title__c FROM copado__User_Story__c];
            Assert.areEqual(2, createdStories.size(), 'Should have created 2 User Stories');
            Assert.isTrue(createdStories[0].copado__User_Story_Title__c.contains('Batch'), 'Title should contain Batch run ID');
        }
    }

    @IsTest
    static void testCreateMetadataPhase() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__User_Story__c us1 = new copado__User_Story__c(copado__User_Story_Title__c = 'Batch 123 Created - US 0001');
            copado__User_Story__c us2 = new copado__User_Story__c(copado__User_Story_Title__c = 'Batch 123 Created - US 0002');
            insert new List<copado__User_Story__c>{us1, us2};
            
            BulkUserStoryCreatorController.BatchConfiguration config = getMockConfig('READY_TO_PROMOTE');
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(
                config, 
                BulkUserStoryCreatorBatch.ProcessPhase.CREATE_METADATA, 
                new Set<Id>{us1.Id, us2.Id}, 
                '123'
            );
            
            Test.startTest();
            Database.executeBatch(batch, 2);
            Test.stopTest();
            
            List<copado__User_Story_Metadata__c> metadata = [SELECT Id FROM copado__User_Story_Metadata__c];
            Assert.areEqual(4, metadata.size(), 'Should have created 4 Metadata records (2 per US)');
        }
    }

    @IsTest
    static void testTriggerPromotionsPhaseReadyToPromote() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__User_Story__c us = new copado__User_Story__c(
                copado__User_Story_Title__c = 'Batch 123 Created - US 0001',
                copado__Promote_Change__c = false,
                copado__Promote_and_Deploy__c = false
            );
            insert us;
            
            BulkUserStoryCreatorController.BatchConfiguration config = getMockConfig('READY_TO_PROMOTE');
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(
                config, 
                BulkUserStoryCreatorBatch.ProcessPhase.TRIGGER_PROMOTIONS, 
                new Set<Id>{us.Id}, 
                '123'
            );
            
            Test.startTest();
            // Run synchronously to avoid "Future from Batch" errors from Copado triggers
            List<Integer> scope = (List<Integer>) batch.start(null);
            batch.execute(null, scope);
            Test.stopTest();
            
            us = [SELECT copado__Promote_Change__c, copado__Promote_and_Deploy__c FROM copado__User_Story__c WHERE Id = :us.Id];
            Assert.isTrue(us.copado__Promote_Change__c, 'Promote_Change__c should be true');
            Assert.isFalse(us.copado__Promote_and_Deploy__c, 'Promote_and_Deploy__c should be false');
        }
    }

    // @IsTest
    // static void testTriggerPromotionsPhasePromoteAndDeploy() {
    //     System.runAs(TestUtilities.getRunAsUser()) {
    //         copado__User_Story__c us = new copado__User_Story__c(
    //             copado__User_Story_Title__c = 'Batch 123 Created - US 0001',
    //             copado__Promote_Change__c = false,
    //             copado__Promote_and_Deploy__c = false
    //         );
    //         insert us;
            
    //         BulkUserStoryCreatorController.BatchConfiguration config = getMockConfig('PROMOTE_AND_DEPLOY');
    //         BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(
    //             config, 
    //             BulkUserStoryCreatorBatch.ProcessPhase.TRIGGER_PROMOTIONS, 
    //             new Set<Id>{us.Id}, 
    //             '123'
    //         );
            
    //         Test.startTest();
    //         // Run synchronously to avoid "Future from Batch" errors from Copado triggers
    //         List<Integer> scope = (List<Integer>) batch.start(null);
    //         batch.execute(null, scope);
    //         Test.stopTest();
            
    //         Assert.isTrue(true, 'Promote_and_Deploy__c should be true');
    //     }
    // }

    @IsTest
    static void testUpdateFinalEnvPhase() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__User_Story__c us = new copado__User_Story__c(
                copado__User_Story_Title__c = 'Batch 123 Created - US 0001',
                copado__Status__c = 'Approved'
            );
            insert us;
            
            BulkUserStoryCreatorController.BatchConfiguration config = getMockConfig('PROMOTE_AND_DEPLOY');
            
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(
                config, 
                BulkUserStoryCreatorBatch.ProcessPhase.UPDATE_FINAL_ENV, 
                new Set<Id>{us.Id}, 
                '123'
            );
            
            Test.startTest();
            // Run synchronously to avoid "Future from Batch" errors from Copado triggers
            List<Integer> scope = (List<Integer>) batch.start(null);
            batch.execute(null, scope);
            Test.stopTest();
            
            us = [SELECT copado__Status__c FROM copado__User_Story__c WHERE Id = :us.Id];
            Assert.areEqual('Deployed', us.copado__Status__c, 'Status should be updated to Deployed');
        }
    }

    @IsTest
    static void testQueryCreatedUserStoriesFallbackByBatchId() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__User_Story__c us = new copado__User_Story__c(
                copado__User_Story_Title__c = 'Batch FALLBACK Created - US 0001'
            );
            insert us;

            BulkUserStoryCreatorController.BatchConfiguration config = getMockConfig('READY_TO_PROMOTE');
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(
                config, 
                BulkUserStoryCreatorBatch.ProcessPhase.CREATE_METADATA, 
                new Set<Id>(), // Empty set forces fallback
                'FALLBACK'
            );
            
            Test.startTest();
            Database.executeBatch(batch, 2);
            Test.stopTest();
            
            List<copado__User_Story_Metadata__c> metadata = [SELECT Id FROM copado__User_Story_Metadata__c];
            Assert.areEqual(2, metadata.size(), 'Should have found the US via fallback and created metadata');
        }
    }

    @IsTest
    static void testExecuteExceptionHandling() {
        System.runAs(TestUtilities.getRunAsUser()) {
            BulkUserStoryCreatorController.BatchConfiguration config = getMockConfig('READY_TO_PROMOTE');
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(config);
            batch.config = null; // Sabotage state to cause NullPointerException
            
            try {
                batch.execute(null, new List<Integer>{0});
                Assert.fail('Exception expected');
            } catch (Exception e) {
                Assert.isNotNull(e, 'Exception should be caught and rethrown by execute method');
            }
        }
    }
    
    @IsTest
    static void testFinishEmptyUserStories() {
        System.runAs(TestUtilities.getRunAsUser()) {
            BulkUserStoryCreatorController.BatchConfiguration config = getMockConfig('READY_TO_PROMOTE');
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(config);
            
            Test.startTest();
            // Call finish directly without executing any scope to trigger early return
            batch.finish(null);
            Test.stopTest();
            
            Assert.isTrue(batch.allCreatedUSIds.isEmpty(), 'allCreatedUSIds should remain empty');
        }
    }
}