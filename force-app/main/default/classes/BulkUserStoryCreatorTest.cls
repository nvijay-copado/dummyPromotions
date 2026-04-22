@IsTest
private class BulkUserStoryCreatorTest {

    @TestSetup
    static void setup() {
        TestUtilities.setup();
    }

    @IsTest
    static void testBulkUSConfigDefaults() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Test.startTest();
            BulkUserStoryCreator.BulkUSConfig config = new BulkUserStoryCreator.BulkUSConfig();
            config.pipelineId = 'a00000000000001AAA';
            config.totalUserStories = 100;
            Test.stopTest();
            
            Assert.areEqual(15, config.userStoriesPerBatch, 'Default user stories per batch should be 15');
            Assert.areEqual(5, config.metadataPerUserStory, 'Default metadata per user story should be 5');
            Assert.areEqual(100, config.totalUserStories, 'Total user stories should match the set value');
            Assert.areEqual('a00000000000001AAA', config.pipelineId, 'Pipeline ID should match the set value');
        }
    }

    @IsTest
    static void testPublicConstructorInitialization() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Set up the configuration
            BulkUserStoryCreator.BulkUSConfig config = new BulkUserStoryCreator.BulkUSConfig();
            config.totalUserStories = 35; 
            config.userStoriesPerBatch = 15;
            
            Test.startTest();
            BulkUserStoryCreator creator = new BulkUserStoryCreator(config);
            Test.stopTest();
            
            // Validate state
            Assert.areEqual(config, creator.config, 'The configuration instance should be stored correctly');
            Assert.areEqual(0, creator.currentBatch, 'Current batch should initialize to 0');
            
            // Math.ceil(35 / 15) = 3
            Assert.areEqual(3, creator.totalBatches, 'Total batches should be calculated correctly using ceiling math');
            Assert.areEqual(BulkUserStoryCreator.ProcessStage.CREATE_USER_STORIES, creator.stage, 'Initial stage should be CREATE_USER_STORIES');
            Assert.isNotNull(creator.createdUserStoryIds, 'Created User Story IDs list should be initialized');
            Assert.isTrue(creator.createdUserStoryIds.isEmpty(), 'Created User Story IDs list should be initially empty');
        }
    }

    @IsTest
    static void testPrivateConstructorChainedExecution() {
        System.runAs(TestUtilities.getRunAsUser()) {
            BulkUserStoryCreator.BulkUSConfig config = new BulkUserStoryCreator.BulkUSConfig();
            config.totalUserStories = 50;
            List<Id> mockIds = new List<Id>{ 'a01000000000001AAA', 'a01000000000002AAA' };
            
            Test.startTest();
            // Initialize via the private constructor to simulate chaining
            BulkUserStoryCreator creator = new BulkUserStoryCreator(
                config, 
                1, // currentBatch
                4, // totalBatches
                BulkUserStoryCreator.ProcessStage.CREATE_METADATA, 
                mockIds
            );
            Test.stopTest();
            
            // Validate state restoration
            Assert.areEqual(1, creator.currentBatch, 'Current batch should match the provided value');
            Assert.areEqual(4, creator.totalBatches, 'Total batches should match the provided value');
            Assert.areEqual(BulkUserStoryCreator.ProcessStage.CREATE_METADATA, creator.stage, 'Stage should match the provided value');
            Assert.areEqual(2, creator.createdUserStoryIds.size(), 'Created User Story IDs list should contain the populated IDs');
        }
    }
}