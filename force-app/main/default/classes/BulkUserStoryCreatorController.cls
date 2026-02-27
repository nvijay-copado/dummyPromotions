public with sharing class BulkUserStoryCreatorController {
    
    @AuraEnabled
    public static List<LookupOption> getPipelines() {
        List<LookupOption> options = new List<LookupOption>();
        
        for(copado__Deployment_Flow__c pipeline : [
            SELECT Id, Name
            FROM copado__Deployment_Flow__c
            WHERE copado__Active__c = true
            ORDER BY Name
            LIMIT 1000
        ]) {
            options.add(new LookupOption(pipeline.Id, pipeline.Name));
        }
        
        return options;
    }
    
    @AuraEnabled
    public static List<LookupOption> getProjectsByPipeline(Id pipelineId) {
        List<LookupOption> options = new List<LookupOption>();
        
        if(pipelineId == null) {
            return options;
        }
        
        for(copado__Project__c project : [
            SELECT Id, Name
            FROM copado__Project__c
            WHERE copado__Deployment_Flow__c = :pipelineId
            ORDER BY Name
            LIMIT 1000
        ]) {
            options.add(new LookupOption(project.Id, project.Name));
        }
        
        return options;
    }
    
    @AuraEnabled
    public static List<LookupOption> getReleasesByProject(Id projectId) {
        List<LookupOption> options = new List<LookupOption>();
        
        if(projectId == null) {
            return options;
        }
        
        options.add(new LookupOption(null, '-- None (Optional) --'));
        
        for(copado__Release__c release : [
            SELECT Id, Name, copado__Version__c
            FROM copado__Release__c
            WHERE copado__Project__c = :projectId
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ]) {
            String label = release.Name;
            if(release.copado__Version__c != null) {
                label += ' (v' + release.copado__Version__c + ')';
            }
            options.add(new LookupOption(release.Id, label));
        }
        
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getUserStoryRecordTypes() {
        List<LookupOption> options = new List<LookupOption>();
        
        Schema.DescribeSObjectResult describe = copado__User_Story__c.SObjectType.getDescribe();
        
        for(Schema.RecordTypeInfo rt : describe.getRecordTypeInfos()) {
            if(rt.isAvailable() && !rt.isMaster()) {
                options.add(new LookupOption(rt.getRecordTypeId(), rt.getName()));
            }
        }
        
        return options;
    }
    
    @AuraEnabled
    public static PipelineDetails getPipelineDetails(Id pipelineId) {
        if(pipelineId == null) {
            return null;
        }
        
        copado__Deployment_Flow__c pipeline = [
            SELECT Id, Name,
                   (SELECT Id, copado__Source_Environment__c, copado__Destination_Environment__c,
                           copado__Source_Environment__r.Name, copado__Destination_Environment__r.Name
                    FROM copado__Deployment_Flow_Steps__r
                    ORDER BY CreatedDate)
            FROM copado__Deployment_Flow__c
            WHERE Id = :pipelineId
            LIMIT 1
        ];
        
        PipelineDetails details = new PipelineDetails();
        details.pipelineName = pipeline.Name;
        details.environments = new List<EnvironmentInfo>();
        
        Set<Id> envIds = new Set<Id>();
        List<Id> orderedEnvIds = new List<Id>();
        
        if(!pipeline.copado__Deployment_Flow_Steps__r.isEmpty()) {
            copado__Deployment_Flow_Step__c firstStep = pipeline.copado__Deployment_Flow_Steps__r[0];
            
            if(firstStep.copado__Source_Environment__c != null && !envIds.contains(firstStep.copado__Source_Environment__c)) {
                orderedEnvIds.add(firstStep.copado__Source_Environment__c);
                envIds.add(firstStep.copado__Source_Environment__c);
                
                EnvironmentInfo envInfo = new EnvironmentInfo();
                envInfo.id = firstStep.copado__Source_Environment__c;
                envInfo.name = firstStep.copado__Source_Environment__r.Name;
                envInfo.stepNumber = 1;
                details.environments.add(envInfo);
            }
        }
        
        Integer stepNum = 2;
        for(copado__Deployment_Flow_Step__c step : pipeline.copado__Deployment_Flow_Steps__r) {
            if(step.copado__Destination_Environment__c != null && !envIds.contains(step.copado__Destination_Environment__c)) {
                orderedEnvIds.add(step.copado__Destination_Environment__c);
                envIds.add(step.copado__Destination_Environment__c);
                
                EnvironmentInfo envInfo = new EnvironmentInfo();
                envInfo.id = step.copado__Destination_Environment__c;
                envInfo.name = step.copado__Destination_Environment__r.Name;
                envInfo.stepNumber = stepNum++;
                details.environments.add(envInfo);
            }
        }
        
        details.totalEnvironments = orderedEnvIds.size();
        details.environmentIds = orderedEnvIds;
        
        if(!orderedEnvIds.isEmpty()) {
            details.firstEnvironmentId = orderedEnvIds[0];
            details.finalEnvironmentId = orderedEnvIds[orderedEnvIds.size() - 1];
        }
        
        return details;
    }
    
    @AuraEnabled
    public static ValidationResult validateConfiguration(String configJson) {
        ValidationResult result = new ValidationResult();
        result.isValid = true;
        result.errors = new List<String>();
        result.warnings = new List<String>();
        
        System.debug('=====configJson===='+configJson);
        
        try {
            // Deserialize the JSON string into a Map first
            Map<String, Object> configMap = (Map<String, Object>)JSON.deserializeUntyped(configJson);
            
            System.debug('=====configMap===='+configMap);
            
            // Extract values from the map
            Id pipelineId = (Id)configMap.get('pipelineId');
            Id projectId = (Id)configMap.get('projectId');
            Id userStoryRecordTypeId = (Id)configMap.get('userStoryRecordTypeId');
            Integer totalUserStories = (Integer)configMap.get('totalUserStories');
            Integer userStoriesPerBatch = (Integer)configMap.get('userStoriesPerBatch');
            Integer metadataPerUserStory = (Integer)configMap.get('metadataPerUserStory');
            
            System.debug('=====pipelineId===='+pipelineId);
            System.debug('=====projectId===='+projectId);
            System.debug('=====totalUserStories===='+totalUserStories);
            
            if(String.isBlank(pipelineId)) {
                result.errors.add('Pipeline is required');
                result.isValid = false;
            }

            if(String.isBlank(projectId)) {
                result.errors.add('Project is required');
                result.isValid = false;
            }

            if(String.isBlank(userStoryRecordTypeId)) {
                result.errors.add('User Story Record Type is required');
                result.isValid = false;
            }

            if(totalUserStories == null || totalUserStories <= 0) {
                result.errors.add('Total User Stories must be greater than 0');
                result.isValid = false;
            }

            if(userStoriesPerBatch == null || userStoriesPerBatch <= 0) {
                result.errors.add('User Stories per Batch must be greater than 0');
                result.isValid = false;
            }

            if(metadataPerUserStory == null || metadataPerUserStory < 0) {
                result.errors.add('Metadata per User Story cannot be negative');
                result.isValid = false;
            }

            if(totalUserStories != null && totalUserStories > 10000) {
                result.warnings.add('Creating more than 10,000 User Stories may take a very long time');
            }

            if(userStoriesPerBatch != null && userStoriesPerBatch > 50) {
                result.warnings.add('Batch size > 50 may cause governor limit issues during promotions');
            }

            if(metadataPerUserStory != null && metadataPerUserStory > 100) {
                result.warnings.add('More than 100 metadata items per User Story may impact performance');
            }

            if(result.isValid) {
                result.estimatedBatches = (Integer)Math.ceil(Decimal.valueOf(totalUserStories) / userStoriesPerBatch);
                result.estimatedTimeMinutes = result.estimatedBatches * 4 * 2;
                result.totalMetadataRecords = totalUserStories * metadataPerUserStory;
            }
        } catch(Exception e) {
            System.debug('=====Exception in validateConfiguration===='+e.getMessage());
            System.debug('=====Stack trace===='+e.getStackTraceString());
            result.errors.add('Error parsing configuration: ' + e.getMessage());
            result.isValid = false;
        }

        return result;
    }
    
    @AuraEnabled
    public static BatchStartResult startBatch(String configJson) {
        BatchStartResult result = new BatchStartResult();
        
        try {
            BatchConfiguration config = (BatchConfiguration)JSON.deserialize(configJson, BatchConfiguration.class);
            
            ValidationResult validation = validateConfiguration(configJson);
            if(!validation.isValid) {
                result.success = false;
                result.message = 'Configuration validation failed: ' + String.join(validation.errors, '; ');
                return result;
            }
            
            // Pass the config directly to the batch
            BulkUserStoryCreatorBatch batch = new BulkUserStoryCreatorBatch(config);
            Id batchId = Database.executeBatch(batch, config.userStoriesPerBatch);
            
            // Store config for reference
            Map<String, Object> batchConfigMap = new Map<String, Object>();
            batchConfigMap.put('pipelineId', config.pipelineId);
            batchConfigMap.put('projectId', config.projectId);
            batchConfigMap.put('releaseId', config.releaseId);
            batchConfigMap.put('userStoryRecordTypeId', config.userStoryRecordTypeId);
            batchConfigMap.put('totalUserStories', config.totalUserStories);
            batchConfigMap.put('userStoriesPerBatch', config.userStoriesPerBatch);
            batchConfigMap.put('metadataPerUserStory', config.metadataPerUserStory);
            batchConfigMap.put('selectedEnvironmentId', config.selectedEnvironmentId);
            batchConfigMap.put('finalEnvironmentId', config.finalEnvironmentId);
            batchConfigMap.put('executionMode', config.executionMode);
            
            result.success = true;
            result.batchId = batchId;
            result.configJson = JSON.serialize(batchConfigMap);
            result.message = 'Batch job started successfully';
            
        } catch(Exception e) {
            result.success = false;
            result.message = 'Error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString();
        }
        
        return result;
    }

    @AuraEnabled
    public static BatchJobStatus getBatchStatus(Id batchId) {
        if(batchId == null) {
            return null;
        }
        
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems,
                   CreatedDate, CompletedDate, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :batchId
            LIMIT 1
        ];
        
        if(jobs.isEmpty()) {
            return null;
        }
        
        AsyncApexJob job = jobs[0];
        
        BatchJobStatus status = new BatchJobStatus();
        status.batchId = job.Id;
        status.status = job.Status;
        status.progress = job.TotalJobItems > 0 ? 
            (Integer)((Decimal.valueOf(job.JobItemsProcessed) / job.TotalJobItems) * 100) : 0;
        status.jobItemsProcessed = job.JobItemsProcessed;
        status.totalJobItems = job.TotalJobItems;
        status.numberOfErrors = job.NumberOfErrors;
        status.createdDate = job.CreatedDate;
        status.completedDate = job.CompletedDate;
        status.extendedStatus = job.ExtendedStatus;
        status.isCompleted = (job.Status == 'Completed' || job.Status == 'Failed' || job.Status == 'Aborted');
        
        return status;
    }

    @AuraEnabled(cacheable=false)
    public static UserStoryListResult getUserStoriesCreatedByBatch(String configJson, String batchId, Integer limitRecords, Integer offsetRecords) {
        UserStoryListResult result = new UserStoryListResult();
        result.userStories = new List<UserStoryInfo>();
        result.totalCount = 0;
        
        System.debug('===== getUserStoriesCreatedByBatch configJson===='+configJson);
        
        try {
            if(String.isBlank(configJson)) {
                return result;
            }

             if(batchId == null) {
                result.success = false;
                result.errorMessage = 'Batch ID is required';
                return result;
            }
            
            Map<String, Object> config = (Map<String, Object>)JSON.deserializeUntyped(configJson);
            Id projectId = (Id)config.get('projectId');
            Id releaseId = (Id)config.get('releaseId');
            
            if(projectId == null) {
                return result;
            }

            // Build the search pattern for the User Story Title
            // Assuming the title contains the batchId somewhere in it
            String searchPattern = '%' + String.valueOf(batchId) + '%';
            
            System.debug('=====searchPattern===='+searchPattern);
            
            // Build dynamic query
            String query = 'SELECT Id, Name, copado__User_Story_Title__c, copado__Status__c, ' +
                        'copado__Environment__r.Name, copado__Project__r.Name, ' +
                        'copado__Release__r.Name, CreatedDate, CreatedBy.Name, ' +
                        'copado__Progress__c, copado__Total_Story_Points__c ' +
                        'FROM copado__User_Story__c ' +
                        'WHERE copado__Project__c = :projectId AND copado__User_Story_Title__c LIKE :searchPattern';
            
            if(releaseId != null) {
                query += ' AND copado__Release__c = :releaseId';
            }
            
            // Order by most recent first
            query += ' ORDER BY CreatedDate DESC ';
            
            
            // Add limit and offset
            if(limitRecords != null && limitRecords > 0) {
                query += 'LIMIT :limitRecords ';
            }
            if(offsetRecords != null && offsetRecords > 0) {
                query += 'OFFSET :offsetRecords';
            }
            
            List<copado__User_Story__c> userStories = Database.query(query);
            result.totalCount = userStories.size();
            for(copado__User_Story__c us : userStories) {
                UserStoryInfo info = new UserStoryInfo();
                info.id = us.Id;
                info.name = us.Name;
                info.title = us.copado__User_Story_Title__c;
                info.status = us.copado__Status__c;
                info.environmentName = us.copado__Environment__r?.Name;
                info.projectName = us.copado__Project__r?.Name;
                info.releaseName = us.copado__Release__r?.Name;
                info.createdDate = us.CreatedDate;
                info.createdByName = us.CreatedBy.Name;
                info.progress = us.copado__Progress__c != null ? us.copado__Progress__c : 0;
                info.storyPoints = us.copado__Total_Story_Points__c;
                
                result.userStories.add(info);
            }
            
            result.success = true;
            
        } catch(Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
        }
        
        return result;
    }

    @AuraEnabled
    public static MetadataCountResult getMetadataCountForUserStory(Id userStoryId) {
        MetadataCountResult result = new MetadataCountResult();
        result.count = 0;
        
        try {
            if(userStoryId == null) {
                return result;
            }
            
            result.count = [
                SELECT COUNT()
                FROM copado__User_Story_Metadata__c
                WHERE copado__User_Story__c = :userStoryId
            ];
            
            result.success = true;
            
        } catch(Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
        }
        
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static BatchSummary getBatchCreationSummary(String configJson) {
        BatchSummary summary = new BatchSummary();
        
        try {
            if(String.isBlank(configJson)) {
                return summary;
            }
            
            Map<String, Object> config = (Map<String, Object>)JSON.deserializeUntyped(configJson);
            Id projectId = (Id)config.get('projectId');
            Id releaseId = (Id)config.get('releaseId');
            
            if(projectId == null) {
                return summary;
            }
            
            // Get user story counts by status
            String query = 'SELECT copado__Status__c, COUNT(Id) total ' +
                        'FROM copado__User_Story__c ' +
                        'WHERE copado__Project__c = :projectId ';
            
            if(releaseId != null) {
                query += 'AND copado__Release__c = :releaseId ';
            }
            
            query += 'GROUP BY copado__Status__c';
            
            List<AggregateResult> results = Database.query(query);
            
            summary.statusBreakdown = new Map<String, Integer>();
            summary.totalUserStories = 0;
            
            for(AggregateResult ar : results) {
                String status = (String)ar.get('copado__Status__c');
                Integer count = (Integer)ar.get('total');
                summary.statusBreakdown.put(status != null ? status : 'No Status', count);
                summary.totalUserStories += count;
            }
            
            // Get total metadata count
            String metadataQuery = 'SELECT COUNT() ' +
                                'FROM copado__User_Story_Metadata__c ' +
                                'WHERE copado__User_Story__r.copado__Project__c = :projectId ';
            
            if(releaseId != null) {
                metadataQuery += 'AND copado__User_Story__r.copado__Release__c = :releaseId';
            }
            
            summary.totalMetadata = Database.countQuery(metadataQuery);
            summary.success = true;
            
        } catch(Exception e) {
            summary.success = false;
            summary.errorMessage = e.getMessage();
        }
        
        return summary;
    }

    // Add these inner classes at the end of the controller
    public class UserStoryInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String status;
        @AuraEnabled public String environmentName;
        @AuraEnabled public String projectName;
        @AuraEnabled public String releaseName;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Decimal progress;
        @AuraEnabled public Decimal storyPoints;
    }

    public class UserStoryListResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public List<UserStoryInfo> userStories;
        @AuraEnabled public Integer totalCount;
    }

    public class MetadataCountResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer count;
    }

    public class BatchSummary {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer totalUserStories;
        @AuraEnabled public Integer totalMetadata;
        @AuraEnabled public Map<String, Integer> statusBreakdown;
    }
    
    public class LookupOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        
        public LookupOption(Id value, String label) {
            this.value = value;
            this.label = label;
        }
    }
    
    public class PipelineDetails {
        @AuraEnabled public String pipelineName;
        @AuraEnabled public Integer totalEnvironments;
        @AuraEnabled public List<EnvironmentInfo> environments;
        @AuraEnabled public List<Id> environmentIds;
        @AuraEnabled public Id firstEnvironmentId;
        @AuraEnabled public Id finalEnvironmentId;
    }
    
    public class EnvironmentInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer stepNumber;
    }
    
    public class BatchConfiguration {
        @AuraEnabled
        public String pipelineId;
        @AuraEnabled
        public String projectId;
        @AuraEnabled 
        public String releaseId;
        @AuraEnabled
        public String userStoryRecordTypeId;
        @AuraEnabled
        public Integer totalUserStories;
        @AuraEnabled
        public Integer userStoriesPerBatch;
        @AuraEnabled
        public Integer metadataPerUserStory;
        @AuraEnabled
        public Id selectedEnvironmentId;
        @AuraEnabled
        public Id finalEnvironmentId;
        @AuraEnabled
        public String executionMode;
    }
    
    public class ValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public List<String> errors;
        @AuraEnabled public List<String> warnings;
        @AuraEnabled public Integer estimatedBatches;
        @AuraEnabled public Integer estimatedTimeMinutes;
        @AuraEnabled public Integer totalMetadataRecords;
    }
    
    public class BatchStartResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id batchId;
        @AuraEnabled public String configJson;
    }
    
    public class BatchJobStatus {
        @AuraEnabled public Id batchId;
        @AuraEnabled public String status;
        @AuraEnabled public Integer progress;
        @AuraEnabled public Integer jobItemsProcessed;
        @AuraEnabled public Integer totalJobItems;
        @AuraEnabled public Integer numberOfErrors;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public DateTime completedDate;
        @AuraEnabled public String extendedStatus;
        @AuraEnabled public Boolean isCompleted;
    }
}
