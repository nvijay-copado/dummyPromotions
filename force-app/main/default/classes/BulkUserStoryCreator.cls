public class BulkUserStoryCreator {
    
    private BulkUSConfig config;
    private Integer currentBatch;
    private Integer totalBatches;
    private ProcessStage stage;
    private List<Id> createdUserStoryIds;
    
    public enum ProcessStage {
        CREATE_USER_STORIES,
        CREATE_METADATA,
        TRIGGER_PROMOTIONS,
        UPDATE_TO_FINAL_ENV
    }
    
    // Configuration wrapper
    public class BulkUSConfig {
        public String pipelineId;
        public String userStoryRecordTypeId;
        public String releaseRecordId;
        public Integer totalUserStories;
        public Integer userStoriesPerBatch;
        public Integer metadataPerUserStory;
        public List<Id> environmentIds;
        public Id projectId;
        public Id finalEnvironmentId;
        
        public BulkUSConfig() {
            this.userStoriesPerBatch = 15; // Default safe batch size
            this.metadataPerUserStory = 5;
        }
    }
    
    // Constructor for initial execution
    public BulkUserStoryCreator(BulkUSConfig config) {
        this.config = config;
        this.currentBatch = 0;
        this.totalBatches = (Integer)Math.ceil((Decimal)config.totalUserStories / config.userStoriesPerBatch);
        this.stage = ProcessStage.CREATE_USER_STORIES;
        this.createdUserStoryIds = new List<Id>();
    }
    
    // Constructor for chained execution
    private BulkUserStoryCreator(BulkUSConfig config, Integer currentBatch, Integer totalBatches, 
                                  ProcessStage stage, List<Id> createdUserStoryIds) {
        this.config = config;
        this.currentBatch = currentBatch;
        this.totalBatches = totalBatches;
        this.stage = stage;
        this.createdUserStoryIds = createdUserStoryIds;
    }
}