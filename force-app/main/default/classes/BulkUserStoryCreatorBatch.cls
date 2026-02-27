public class BulkUserStoryCreatorBatch implements Database.Batchable<Integer>, Database.Stateful {
    
    private BulkUserStoryCreator.BulkUSConfig config;
    private ProcessPhase phase;
    private List<Id> createdUserStoryIds;
    private Set<Id> allCreatedUSIds; // Track all created IDs across batches
    private Integer totalProcessed = 0;
    private String batchRunId; // Unique identifier for this batch run
    
    public enum ProcessPhase {
        CREATE_USER_STORIES,
        CREATE_METADATA,
        TRIGGER_PROMOTIONS,
        UPDATE_FINAL_ENV
    }
    
    // Constructor for initial batch execution
    public BulkUserStoryCreatorBatch(BulkUserStoryCreator.BulkUSConfig config) {
        this.config = config;
        this.phase = ProcessPhase.CREATE_USER_STORIES;
        this.createdUserStoryIds = new List<Id>();
        this.allCreatedUSIds = new Set<Id>();
        this.batchRunId = String.valueOf(DateTime.now().getTime()); // Unique run ID
        System.debug('Batch Run ID: ' + this.batchRunId);
    }
    
    // Constructor for chaining between phases
    private BulkUserStoryCreatorBatch(BulkUserStoryCreator.BulkUSConfig config, ProcessPhase phase, Set<Id> allCreatedUSIds, String batchRunId) {
        this.config = config;
        this.phase = phase;
        this.createdUserStoryIds = new List<Id>();
        this.allCreatedUSIds = allCreatedUSIds != null ? allCreatedUSIds : new Set<Id>();
        this.batchRunId = batchRunId;
    }
    
    public Iterable<Integer> start(Database.BatchableContext bc) {
        System.debug('========================================');
        System.debug('Starting phase: ' + phase);
        System.debug('Batch Run ID: ' + batchRunId);
        System.debug('========================================');
        
        List<Integer> indexes = new List<Integer>();
        
        if(phase == ProcessPhase.CREATE_USER_STORIES) {
            // Create indexes for new User Stories
            for(Integer i = 0; i < config.totalUserStories; i++) {
                indexes.add(i);
            }
            System.debug('Will create ' + indexes.size() + ' User Stories');
        } else {
            // For other phases, work with created User Stories
            if(allCreatedUSIds == null || allCreatedUSIds.isEmpty()) {
                System.debug('Re-querying User Stories for phase: ' + phase);
                allCreatedUSIds = queryCreatedUserStories();
                System.debug('Found ' + allCreatedUSIds.size() + ' User Stories');
            }
            
            if(allCreatedUSIds.isEmpty()) {
                System.debug(LoggingLevel.ERROR, 'CRITICAL ERROR: No User Stories found for phase ' + phase);
                return indexes; // Return empty list to prevent errors
            }
            
            createdUserStoryIds = new List<Id>(allCreatedUSIds);
            
            // Create indexes for the User Stories
            for(Integer i = 0; i < createdUserStoryIds.size(); i++) {
                indexes.add(i);
            }
            
            System.debug('Processing ' + indexes.size() + ' User Stories in phase: ' + phase);
        }
        
        return indexes;
    }
    
    public void execute(Database.BatchableContext bc, List<Integer> scope) {
        System.debug('Executing batch for phase: ' + phase + ', scope size: ' + scope.size());
        
        try {
            switch on phase {
                when CREATE_USER_STORIES {
                    createUserStoriesForScope(scope);
                }
                when CREATE_METADATA {
                    createMetadataForScope(scope);
                }
                when TRIGGER_PROMOTIONS {
                    triggerPromotionsForScope(scope);
                }
                when UPDATE_FINAL_ENV {
                    updateFinalEnvironmentForScope(scope);
                }
            }
            totalProcessed += scope.size();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Batch error in phase ' + phase + ': ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw e; // Re-throw to ensure batch failure is visible
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('========================================');
        System.debug('Completed phase: ' + phase);
        System.debug('Total processed in this phase: ' + totalProcessed);
        System.debug('Tracked User Story IDs: ' + allCreatedUSIds.size());
        System.debug('========================================');
        
        // Chain to next phase
        switch on phase {
            when CREATE_USER_STORIES {
                System.debug('User Stories created. Starting CREATE_METADATA phase...');
                
                if(allCreatedUSIds.isEmpty()) {
                    System.debug(LoggingLevel.ERROR, 'ERROR: No User Stories were created!');
                    return;
                }
                
                System.debug('Will create metadata for ' + allCreatedUSIds.size() + ' User Stories');
                
                BulkUserStoryCreatorBatch nextBatch = new BulkUserStoryCreatorBatch(
                    config, ProcessPhase.CREATE_METADATA, allCreatedUSIds, batchRunId
                );
                Database.executeBatch(nextBatch, config.userStoriesPerBatch);
            }
            when CREATE_METADATA {
                System.debug('Metadata creation completed. Starting TRIGGER_PROMOTIONS phase...');
                
                if(allCreatedUSIds == null || allCreatedUSIds.isEmpty()) {
                    System.debug('Re-querying User Stories before triggering promotions...');
                    allCreatedUSIds = queryCreatedUserStories();
                }
                
                System.debug('Will trigger promotions for ' + allCreatedUSIds.size() + ' User Stories');
                
                BulkUserStoryCreatorBatch nextBatch = new BulkUserStoryCreatorBatch(
                    config, ProcessPhase.TRIGGER_PROMOTIONS, allCreatedUSIds, batchRunId
                );
                Database.executeBatch(nextBatch, config.userStoriesPerBatch);
            }
            when TRIGGER_PROMOTIONS {
                System.debug('Promotions triggered successfully');
                System.debug('NOTE: Waiting for Copado promotions to process...');
                System.debug('Starting UPDATE_FINAL_ENV phase...');
                
                if(allCreatedUSIds == null || allCreatedUSIds.isEmpty()) {
                    allCreatedUSIds = queryCreatedUserStories();
                }
                
                BulkUserStoryCreatorBatch nextBatch = new BulkUserStoryCreatorBatch(
                    config, ProcessPhase.UPDATE_FINAL_ENV, allCreatedUSIds, batchRunId
                );
                Database.executeBatch(nextBatch, config.userStoriesPerBatch);
            }
            when UPDATE_FINAL_ENV {
                System.debug('========================================');
                System.debug('✓✓✓ ALL PHASES COMPLETED SUCCESSFULLY! ✓✓✓');
                System.debug('========================================');
                System.debug('Batch Run ID: ' + batchRunId);
                System.debug('Total User Stories processed: ' + allCreatedUSIds.size());
                System.debug('');
                System.debug('Next Steps:');
                System.debug('1. Verify User Stories created: ' + allCreatedUSIds.size());
                System.debug('2. Check metadata records attached');
                System.debug('3. Verify promotions were triggered');
                System.debug('4. Confirm final environment updates');
                System.debug('========================================');
            }
        }
    }
    
    // Create User Stories in the current scope
    private void createUserStoriesForScope(List<Integer> scope) {
        List<copado__User_Story__c> uss = new List<copado__User_Story__c>();
        
        for(Integer i : scope) {
            uss.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Batch ' + batchRunId + ' - US ' + String.valueOf(i + 1).leftPad(4, '0'),
                copado__Project__c = config.projectId,
                copado__Release__c = config.releaseRecordId,
                copado__Environment__c = config.environmentIds[0],
                RecordTypeId = config.userStoryRecordTypeId,
                copado__Status__c = 'Approved',
                copado__Progress__c = 100,
                copado__Apex_Code_Coverage__c = 95
            ));
        }
        
        insert uss;
        
        // Track the created IDs
        for(copado__User_Story__c us : uss) {
            allCreatedUSIds.add(us.Id);
        }
        
        System.debug('Created ' + uss.size() + ' User Stories in this batch. Total tracked: ' + allCreatedUSIds.size());
    }
    
    // Create metadata for User Stories in the current scope
    private void createMetadataForScope(List<Integer> scope) {
        List<Id> batchUSIds = new List<Id>();
        for(Integer i : scope) {
            if(i < createdUserStoryIds.size()) {
                batchUSIds.add(createdUserStoryIds[i]);
            }
        }
        
        if(batchUSIds.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'No User Story IDs to process in this batch!');
            return;
        }
        
        List<copado__User_Story_Metadata__c> metas = new List<copado__User_Story_Metadata__c>();
        List<String> types = new List<String>{'ApexClass', 'ApexTrigger', 'Layout', 'Flow', 'LightningComponentBundle'};
        
        for(Id usId : batchUSIds) {
            for(Integer j = 0; j < config.metadataPerUserStory; j++) {
                metas.add(new copado__User_Story_Metadata__c(
                    copado__User_Story__c = usId,
                    copado__Metadata_API_Name__c = 'Dummy_' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
                    copado__Type__c = types[Math.mod(j, types.size())],
                    copado__Action__c = 'Add'
                ));
            }
        }
        
        insert metas;
        System.debug('Created ' + metas.size() + ' Metadata records for ' + batchUSIds.size() + ' User Stories');
    }
    
    // Trigger promotions for User Stories in the current scope
    private void triggerPromotionsForScope(List<Integer> scope) {
        List<Id> batchUSIds = new List<Id>();
        for(Integer i : scope) {
            if(i < createdUserStoryIds.size()) {
                batchUSIds.add(createdUserStoryIds[i]);
            }
        }
        
        if(batchUSIds.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'ERROR: No User Story IDs to trigger promotions!');
            return;
        }
        
        System.debug('Triggering promotions for ' + batchUSIds.size() + ' User Stories');
        
        List<copado__User_Story__c> ussToUpdate = [
            SELECT Id, copado__Promote_and_Deploy__c 
            FROM copado__User_Story__c 
            WHERE Id IN :batchUSIds
        ];
        
        System.debug('Queried ' + ussToUpdate.size() + ' User Stories to update');
        
        for(copado__User_Story__c us : ussToUpdate) {
            us.copado__Promote_and_Deploy__c = true;
        }
        
        update ussToUpdate;
        System.debug('✓ Successfully set Promote_and_Deploy__c = true for ' + ussToUpdate.size() + ' User Stories');
        
        // Verify the update
        Integer verifyCount = [
            SELECT COUNT() 
            FROM copado__User_Story__c 
            WHERE Id IN :batchUSIds AND copado__Promote_and_Deploy__c = true
        ];
        System.debug('Verification: ' + verifyCount + ' User Stories have Promote_and_Deploy__c = true');
    }
    
    // Update User Stories to final environment
    private void updateFinalEnvironmentForScope(List<Integer> scope) {
        List<Id> batchUSIds = new List<Id>();
        for(Integer i : scope) {
            if(i < createdUserStoryIds.size()) {
                batchUSIds.add(createdUserStoryIds[i]);
            }
        }
        
        if(batchUSIds.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'No User Story IDs to update to final environment!');
            return;
        }
        
        List<copado__User_Story__c> ussToUpdate = [
            SELECT Id, copado__Environment__c, copado__Status__c, copado__Promote_and_Deploy__c
            FROM copado__User_Story__c 
            WHERE Id IN :batchUSIds
        ];
        
        for(copado__User_Story__c us : ussToUpdate) {
            us.copado__Environment__c = config.finalEnvironmentId;
            us.copado__Status__c = 'Deployed';
            us.copado__Promote_and_Deploy__c = false;
        }
        
        update ussToUpdate;
        System.debug('Updated ' + ussToUpdate.size() + ' User Stories to final environment');
    }
    
    // Query User Stories created by this batch run
    private Set<Id> queryCreatedUserStories() {
        Set<Id> usIds = new Set<Id>();
        
        // First try: Use the tracked IDs if available
        if(allCreatedUSIds != null && !allCreatedUSIds.isEmpty()) {
            System.debug('Using tracked User Story IDs: ' + allCreatedUSIds.size());
            return allCreatedUSIds;
        }
        
        // Second try: Query by batch run ID (most reliable)
        List<copado__User_Story__c> ussByBatchId = [
            SELECT Id, copado__User_Story_Title__c, CreatedDate
            FROM copado__User_Story__c 
            WHERE copado__User_Story_Title__c LIKE :('Batch ' + batchRunId + '%')
            ORDER BY CreatedDate DESC
        ];
        
        if(!ussByBatchId.isEmpty()) {
            System.debug('Found ' + ussByBatchId.size() + ' User Stories by Batch Run ID');
            for(copado__User_Story__c us : ussByBatchId) {
                usIds.add(us.Id);
            }
            return usIds;
        }
        
        // Third try: Query by project and recent creation time
        DateTime recentTime = DateTime.now().addHours(-2);
        List<copado__User_Story__c> ussByProject = [
            SELECT Id, CreatedDate
            FROM copado__User_Story__c 
            WHERE copado__Project__c = :config.projectId
            AND CreatedDate >= :recentTime
            ORDER BY CreatedDate DESC
            LIMIT :config.totalUserStories
        ];
        
        System.debug('Fallback query found ' + ussByProject.size() + ' User Stories created in last 2 hours');
        
        for(copado__User_Story__c us : ussByProject) {
            usIds.add(us.Id);
        }
        
        if(usIds.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'WARNING: No User Stories found!');
            System.debug('Batch Run ID: ' + batchRunId);
            System.debug('Project ID: ' + config.projectId);
        }
        
        return usIds;
    }
}