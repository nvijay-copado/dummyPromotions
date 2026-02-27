public with sharing class ExecuteBatch {
    public ExecuteBatch() {
        // ========================================
        // Execute Bulk User Story Creator Batch
        // ========================================

        // STEP 1: Configure your settings
        BulkUserStoryCreator.BulkUSConfig config = new BulkUserStoryCreator.BulkUSConfig();

        // Pipeline/Deployment Flow ID
        config.pipelineId = 'a0W7Q000004YFo4UAG'; // REPLACE WITH YOUR PIPELINE ID

        // User Story Record Type
        config.userStoryRecordTypeId = '0127Q00000027QLQAY'; // REPLACE WITH YOUR RECORD TYPE ID

        // Number of User Stories to create
        config.totalUserStories = 500; // Adjust as needed (e.g., 500, 1000)

        // Batch size (how many User Stories per batch execution)
        config.userStoriesPerBatch = 15; // 15 is recommended for promotions

        // Number of metadata items per User Story
        config.metadataPerUserStory = 4; // Adjust as needed

        // STEP 2: Get the pipeline and environments
        copado__Deployment_Flow__c pipeline = [
            SELECT Id, 
                (SELECT copado__Source_Environment__c, 
                        copado__Destination_Environment__c 
                    FROM copado__Deployment_Flow_Steps__r 
                    ORDER BY CreatedDate) 
            FROM copado__Deployment_Flow__c 
            WHERE Id = :config.pipelineId
            LIMIT 1
        ];

        // Build environment list from pipeline steps
        List<Id> environmentIds = new List<Id>();
        environmentIds.add(pipeline.copado__Deployment_Flow_Steps__r[0].copado__Source_Environment__c);

        for(copado__Deployment_Flow_Step__c step : pipeline.copado__Deployment_Flow_Steps__r) {
            if(!environmentIds.contains(step.copado__Destination_Environment__c)) {
                environmentIds.add(step.copado__Destination_Environment__c);
            }
        }

        config.environmentIds = environmentIds;
        config.finalEnvironmentId = environmentIds[environmentIds.size() - 1];

        System.debug('Environments configured: ' + environmentIds.size());
        System.debug('First Environment: ' + environmentIds[0]);
        System.debug('Final Environment: ' + config.finalEnvironmentId);

        // STEP 3: Get Project ID
        List<copado__Project__c> projects = [
            SELECT Id, Name 
            FROM copado__Project__c 
            WHERE copado__Deployment_Flow__c = :config.pipelineId 
            LIMIT 1
        ];

        if(projects.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'ERROR: No project found for this pipeline!');
            System.debug('Please create a project or update the pipeline ID');
        } else {
            config.projectId = projects[0].Id;
            System.debug('Project ID: ' + config.projectId);
            System.debug('Project Name: ' + projects[0].Name);
        }

        // STEP 4: Optional - Get Release ID
        List<copado__Release__c> releases = [
            SELECT Id, Name 
            FROM copado__Release__c 
            WHERE copado__Project__c = :config.projectId 
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if(!releases.isEmpty()) {
            config.releaseRecordId = releases[0].Id;
            System.debug('Release ID: ' + config.releaseRecordId);
            System.debug('Release Name: ' + releases[0].Name);
        } else {
            System.debug('No release found - User Stories will be created without release');
        }

        // STEP 5: Validate configuration
        System.debug('========================================');
        System.debug('CONFIGURATION SUMMARY');
        System.debug('========================================');
        System.debug('Pipeline ID: ' + config.pipelineId);
        System.debug('Project ID: ' + config.projectId);
        System.debug('Release ID: ' + config.releaseRecordId);
        System.debug('Record Type ID: ' + config.userStoryRecordTypeId);
        System.debug('Total User Stories: ' + config.totalUserStories);
        System.debug('User Stories per Batch: ' + config.userStoriesPerBatch);
        System.debug('Metadata per US: ' + config.metadataPerUserStory);
        System.debug('Environments: ' + config.environmentIds.size());
        System.debug('========================================');

        // STEP 6: Execute the batch
        if(config.projectId != null) {
            System.debug('Starting Bulk User Story Creator Batch...');
            System.debug('This will execute in 4 phases:');
            System.debug('1. CREATE_USER_STORIES');
            System.debug('2. CREATE_METADATA');
            System.debug('3. TRIGGER_PROMOTIONS');
            System.debug('4. UPDATE_FINAL_ENV');
            System.debug('========================================');
            
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(config);
            Id batchId = Database.executeBatch(batch, config.userStoriesPerBatch);
            
            System.debug('✓ Batch started successfully!');
            System.debug('Batch Job ID: ' + batchId);
            System.debug('');
            System.debug('Monitor progress:');
            System.debug('Setup > Apex Jobs > Batch Apex Jobs');
            System.debug('Or query: SELECT Id, Status, JobItemsProcessed, TotalJobItems FROM AsyncApexJob WHERE Id = \'' + batchId + '\'');
        } else {
            System.debug(LoggingLevel.ERROR, '✗ Cannot start batch - missing required configuration');
        }
    }
}