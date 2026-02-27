import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getPipelines from '@salesforce/apex/BulkUserStoryCreatorController.getPipelines';
import getProjectsByPipeline from '@salesforce/apex/BulkUserStoryCreatorController.getProjectsByPipeline';
import getReleasesByProject from '@salesforce/apex/BulkUserStoryCreatorController.getReleasesByProject';
import getUserStoryRecordTypes from '@salesforce/apex/BulkUserStoryCreatorController.getUserStoryRecordTypes';
import getPipelineDetails from '@salesforce/apex/BulkUserStoryCreatorController.getPipelineDetails';
import validateConfiguration from '@salesforce/apex/BulkUserStoryCreatorController.validateConfiguration';
import startBatch from '@salesforce/apex/BulkUserStoryCreatorController.startBatch';
import getBatchStatus from '@salesforce/apex/BulkUserStoryCreatorController.getBatchStatus';
import getUserStoriesCreatedByBatch from '@salesforce/apex/BulkUserStoryCreatorController.getUserStoriesCreatedByBatch';
import getBatchCreationSummary from '@salesforce/apex/BulkUserStoryCreatorController.getBatchCreationSummary';

export default class BulkUserStoryCreator extends NavigationMixin(LightningElement) {
    // Configuration with default values
    @track selectedPipelineId = '';
    @track selectedProjectId = '';
    @track selectedReleaseId = '';
    @track selectedRecordTypeId = '';
    @track totalUserStories = '10';
    @track userStoriesPerBatch = '5';
    @track metadataPerUserStory = '2';

    // Lookup options
    @track pipelineOptions = [];
    @track projectOptions = [];
    @track releaseOptions = [];
    @track recordTypeOptions = [];

    // Pipeline details
    @track pipelineDetails;
    @track selectedEnvironmentId = '';
    @track environmentOptions = [];

    // Validation - IMPORTANT: Only show validation after explicit validation
    @track validationResult = null;
    @track showValidation = false;

    // Batch execution
    @track showExecutionModal = false;
    @track selectedExecutionMode = 'READY_TO_PROMOTE';
    @track batchId;
    @track batchStatus;
    @track batchConfigJson;
    @track isBatchRunning = false;
    @track pollingInterval;

    // User Story List
    @track userStories = [];
    @track totalUserStoriesCount = 0;
    @track currentPage = 1;
    @track pageSize = 25;
    @track showUserStoryList = false;
    @track batchSummary = null;
    @track isLoadingUserStories = false;

    // Loading states
    isLoadingProjects = false;
    isLoadingReleases = false;
    isLoadingPipelineDetails = false;
    isValidating = false;
    isStartingBatch = false;

    // User Story Columns
    userStoryColumns = [
        {
            label: 'User Story',
            fieldName: 'userStoryUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'name' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Title',
            fieldName: 'title',
            type: 'text',
            sortable: true,
            wrapText: true
        },
        {
            label: 'Status',
            fieldName: 'status',
            type: 'text',
            sortable: true
        },
        {
            label: 'Environment',
            fieldName: 'environmentName',
            type: 'text',
            sortable: true
        },
        {
            label: 'Progress',
            fieldName: 'progress',
            type: 'percent',
            typeAttributes: {
                step: '0.01',
                minimumFractionDigits: 0,
                maximumFractionDigits: 0
            },
            cellAttributes: {
                class: { fieldName: 'progressClass' }
            }
        },
        {
            label: 'Created Date',
            fieldName: 'createdDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            },
            sortable: true
        },
        {
            label: 'Created By',
            fieldName: 'createdByName',
            type: 'text',
            sortable: true
        }
    ];

    // Lifecycle hooks
    connectedCallback() {
        console.log('BulkUserStoryCreator - Component initialized');
        this.loadPipelines();
        this.loadRecordTypes();
    }

    disconnectedCallback() {
        console.log('BulkUserStoryCreator - Component disconnected');
        this.stopPolling();
    }

    // Computed properties
    get isConfigurationComplete() {
        const totalUS = parseInt(this.totalUserStories, 10);
        const usPerBatch = parseInt(this.userStoriesPerBatch, 10);
        const metadataPerUS = parseInt(this.metadataPerUserStory, 10);

        const isComplete = this.selectedPipelineId &&
               this.selectedProjectId &&
               this.selectedRecordTypeId &&
               this.selectedEnvironmentId &&
               !isNaN(totalUS) && totalUS > 0 &&
               !isNaN(usPerBatch) && usPerBatch > 0 &&
               !isNaN(metadataPerUS) && metadataPerUS >= 0;

        console.log('isConfigurationComplete:', isComplete, {
            pipelineId: this.selectedPipelineId,
            projectId: this.selectedProjectId,
            recordTypeId: this.selectedRecordTypeId,
            totalUS,
            usPerBatch,
            metadataPerUS
        });

        return isComplete;
    }

    get canStartBatch() {
        const canStart = this.isConfigurationComplete &&
               this.validationResult?.isValid &&
               !this.isBatchRunning;
        
        console.log('canStartBatch:', canStart, {
            isConfigurationComplete: this.isConfigurationComplete,
            isValid: this.validationResult?.isValid,
            isBatchRunning: this.isBatchRunning
        });

        return canStart;
    }

    get hasValidationErrors() {
        // ONLY show errors if validation has been explicitly run
        const hasErrors = this.showValidation && this.validationResult?.errors?.length > 0;
        console.log('hasValidationErrors:', hasErrors, {
            showValidation: this.showValidation,
            errorsCount: this.validationResult?.errors?.length
        });
        return hasErrors;
    }

    get hasValidationWarnings() {
        // ONLY show warnings if validation has been explicitly run
        const hasWarnings = this.showValidation && this.validationResult?.warnings?.length > 0;
        console.log('hasValidationWarnings:', hasWarnings, {
            showValidation: this.showValidation,
            warningsCount: this.validationResult?.warnings?.length
        });
        return hasWarnings;
    }

    get executionModeOptions() {
        return [
            { label: 'Ready to Promote', value: 'READY_TO_PROMOTE' },
            { label: 'Promote & Deploy', value: 'PROMOTE_AND_DEPLOY' }
        ];
    }

    get batchProgressPercentage() {
        return this.batchStatus?.progress || 0;
    }

    get batchProgressVariant() {
        if (!this.batchStatus) return 'base';
        if (this.batchStatus.status === 'Completed') return 'success';
        if (this.batchStatus.status === 'Failed' || this.batchStatus.status === 'Aborted') return 'error';
        return 'base';
    }

    get showBatchStatus() {
        return this.batchId && this.batchStatus;
    }

    get isBatchCompleted() {
        return this.batchStatus?.isCompleted === true;
    }

    get isBatchSuccessful() {
        return this.batchStatus?.status === 'Completed' && this.batchStatus?.numberOfErrors === 0;
    }

    get hasUserStories() {
        return this.userStories && this.userStories.length > 0;
    }

    get totalPages() {
        return Math.ceil(this.totalUserStoriesCount / this.pageSize);
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get pageInfo() {
        if (this.totalUserStoriesCount === 0) return '0 of 0';
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalUserStoriesCount);
        return `${start}-${end} of ${this.totalUserStoriesCount}`;
    }

    get statusBreakdownList() {
        if (!this.batchSummary?.statusBreakdown) return [];
        return Object.entries(this.batchSummary.statusBreakdown).map(([key, value]) => ({
            key: key,
            label: key,
            value: value
        }));
    }

    get showUserStorySection() {
        return this.batchConfigJson && this.isBatchCompleted;
    }

    // Helper method to clear validation
    clearValidation() {
        console.log('clearValidation - Clearing validation state');
        this.validationResult = null;
        this.showValidation = false;
    }

    // Data loading methods
    async loadPipelines() {
        console.log('loadPipelines - Starting');
        try {
            const result = await getPipelines();
            this.pipelineOptions = result;
            console.log('loadPipelines - Success:', result);
        } catch (error) {
            console.error('loadPipelines - Error:', error);
            this.showToast('Error', 'Failed to load pipelines: ' + error.body?.message, 'error');
        }
    }

    async loadRecordTypes() {
        console.log('loadRecordTypes - Starting');
        try {
            const result = await getUserStoryRecordTypes();
            this.recordTypeOptions = result;
            console.log('loadRecordTypes - Success:', result);
            if (result.length === 1) {
                this.selectedRecordTypeId = result[0].value;
                console.log('loadRecordTypes - Auto-selected single record type:', this.selectedRecordTypeId);
            }
        } catch (error) {
            console.error('loadRecordTypes - Error:', error);
            this.showToast('Error', 'Failed to load record types: ' + error.body?.message, 'error');
        }
    }

    async loadProjects(pipelineId) {
        console.log('loadProjects - Starting for pipelineId:', pipelineId);
        if (!pipelineId) {
            this.projectOptions = [];
            console.log('loadProjects - No pipelineId, clearing projects');
            return;
        }

        this.isLoadingProjects = true;
        try {
            const result = await getProjectsByPipeline({ pipelineId });
            this.projectOptions = result;
            console.log('loadProjects - Success:', result);
        } catch (error) {
            console.error('loadProjects - Error:', error);
            this.showToast('Error', 'Failed to load projects: ' + error.body?.message, 'error');
        } finally {
            this.isLoadingProjects = false;
        }
    }

    async loadReleases(projectId) {
        console.log('loadReleases - Starting for projectId:', projectId);
        if (!projectId) {
            this.releaseOptions = [];
            console.log('loadReleases - No projectId, clearing releases');
            return;
        }

        this.isLoadingReleases = true;
        try {
            const result = await getReleasesByProject({ projectId });
            this.releaseOptions = result;
            console.log('loadReleases - Success:', result);
        } catch (error) {
            console.error('loadReleases - Error:', error);
            this.showToast('Error', 'Failed to load releases: ' + error.body?.message, 'error');
        } finally {
            this.isLoadingReleases = false;
        }
    }

    async loadPipelineDetails(pipelineId) {
        console.log('loadPipelineDetails - Starting for pipelineId:', pipelineId);
        if (!pipelineId) {
            this.pipelineDetails = null;
            console.log('loadPipelineDetails - No pipelineId, clearing details');
            return;
        }

        this.isLoadingPipelineDetails = true;
        try {
            const result = await getPipelineDetails({ pipelineId });
            this.pipelineDetails = result;
            console.log('loadPipelineDetails - Success:', result);

            // Transform environments to options
            if (result?.environments) {
                this.environmentOptions = result.environments.map(env => ({
                    label: env.name,
                    value: env.id
                }));
            }

            // Auto-select first environment
            if (result?.firstEnvironmentId) {
                this.selectedEnvironmentId = result.firstEnvironmentId;
                console.log('loadPipelineDetails - Auto-selected environment:', this.selectedEnvironmentId);
            }
        } catch (error) {
            console.error('loadPipelineDetails - Error:', error);
            this.showToast('Error', 'Failed to load pipeline details: ' + error.body?.message, 'error');
        } finally {
            this.isLoadingPipelineDetails = false;
        }
    }

    // Event handlers
    handlePipelineChange(event) {
        this.selectedPipelineId = event.detail.value;
        console.log('handlePipelineChange - New value:', this.selectedPipelineId);
        
        this.selectedProjectId = '';
        this.selectedReleaseId = '';
        this.pipelineDetails = null;
        this.selectedEnvironmentId = '';
        this.environmentOptions = [];
        this.clearValidation();

        this.loadProjects(this.selectedPipelineId);
        this.loadPipelineDetails(this.selectedPipelineId);
    }

    handleProjectChange(event) {
        this.selectedProjectId = event.detail.value;
        console.log('handleProjectChange - New value:', this.selectedProjectId);
        
        this.selectedReleaseId = '';
        this.clearValidation();

        this.loadReleases(this.selectedProjectId);
    }

    handleReleaseChange(event) {
        this.selectedReleaseId = event.detail.value;
        console.log('handleReleaseChange - New value:', this.selectedReleaseId);
        this.clearValidation();
    }

    handleRecordTypeChange(event) {
        this.selectedRecordTypeId = event.detail.value;
        console.log('handleRecordTypeChange - New value:', this.selectedRecordTypeId);
        this.clearValidation();
    }

    handleTotalUserStoriesChange(event) {
        this.totalUserStories = event.detail.value;
        console.log('handleTotalUserStoriesChange - New value:', this.totalUserStories);
        this.clearValidation();
    }

    handleUserStoriesPerBatchChange(event) {
        this.userStoriesPerBatch = event.detail.value;
        console.log('handleUserStoriesPerBatchChange - New value:', this.userStoriesPerBatch);
        this.clearValidation();
    }

    handleMetadataPerUserStoryChange(event) {
        this.metadataPerUserStory = event.detail.value;
        console.log('handleMetadataPerUserStoryChange - New value:', this.metadataPerUserStory);
        this.clearValidation();
    }

    handleEnvironmentChange(event) {
        this.selectedEnvironmentId = event.detail.value;
        console.log('handleEnvironmentChange - New value:', this.selectedEnvironmentId);
        this.clearValidation();
    }

    // Validation
    async handleValidate() {
        console.log('handleValidate - Starting validation');
        
        if (!this.isConfigurationComplete) {
            console.warn('handleValidate - Configuration incomplete');
            this.showToast('Warning', 'Please complete all required fields', 'warning');
            return;
        }

        this.isValidating = true;
        this.clearValidation(); // Clear any previous validation
        
        try {
            const config = {
                pipelineId: this.selectedPipelineId,
                projectId: this.selectedProjectId,
                releaseId: this.selectedReleaseId || null,
                userStoryRecordTypeId: this.selectedRecordTypeId,
                totalUserStories: parseInt(this.totalUserStories, 10),
                userStoriesPerBatch: parseInt(this.userStoriesPerBatch, 10),
                metadataPerUserStory: parseInt(this.metadataPerUserStory, 10),
                selectedEnvironmentId: this.selectedEnvironmentId,
                finalEnvironmentId: this.pipelineDetails?.finalEnvironmentId
            };

            console.log('handleValidate - Sending config to Apex:', JSON.stringify(config, null, 2));

            const result = await validateConfiguration({ configJson: JSON.stringify(config) });
            
            console.log('handleValidate - Received result from Apex:', JSON.stringify(result, null, 2));
            
            this.validationResult = result;
            this.showValidation = true; // ONLY set to true after successful validation call

            if (result.isValid) {
                console.log('handleValidate - Validation PASSED');
                this.showToast('Success', 'Configuration is valid!', 'success');
            } else {
                console.warn('handleValidate - Validation FAILED with errors:', result.errors);
                this.showToast('Validation Failed', result.errors.join('; '), 'error');
            }
        } catch (error) {
            console.error('handleValidate - Exception occurred:', error);
            this.showToast('Error', 'Validation failed: ' + error.body?.message, 'error');
            this.clearValidation(); // Clear on error
        } finally {
            this.isValidating = false;
            console.log('handleValidate - Completed. showValidation:', this.showValidation);
        }
    }

    // Batch execution
    handleStartBatch() {
        console.log('handleStartBatch - Opening modal');
        
        if (!this.canStartBatch) {
            console.warn('handleStartBatch - Cannot start batch');
            this.showToast('Warning', 'Please validate configuration first', 'warning');
            return;
        }
        
        this.showExecutionModal = true;
    }

    handleCloseModal() {
        this.showExecutionModal = false;
    }

    handleExecutionModeChange(event) {
        this.selectedExecutionMode = event.detail.value;
    }

    async handleConfirmBatch() {
        console.log('handleConfirmBatch - Starting batch');
        this.showExecutionModal = false;

        this.isStartingBatch = true;
        try {
            const config = {
                pipelineId: this.selectedPipelineId,
                projectId: this.selectedProjectId,
                releaseId: this.selectedReleaseId || null,
                userStoryRecordTypeId: this.selectedRecordTypeId,
                totalUserStories: parseInt(this.totalUserStories, 10),
                userStoriesPerBatch: parseInt(this.userStoriesPerBatch, 10),
                metadataPerUserStory: parseInt(this.metadataPerUserStory, 10),
                selectedEnvironmentId: this.selectedEnvironmentId,
                finalEnvironmentId: this.pipelineDetails?.finalEnvironmentId,
                executionMode: this.selectedExecutionMode
            };

            const configJson = JSON.stringify(config);
            console.log('handleConfirmBatch - Sending config to Apex:', configJson);

            const result = await startBatch({ configJson });
            console.log('handleConfirmBatch - Received result:', result);

            if (result.success) {
                this.batchId = result.batchId;
                this.batchConfigJson = result.configJson;
                this.isBatchRunning = true;
                console.log('handleConfirmBatch - Batch started successfully. BatchId:', this.batchId);
                this.showToast('Success', 'Batch job started successfully!', 'success');
                this.startPolling();
            } else {
                console.error('handleConfirmBatch - Batch start failed:', result.message);
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('handleConfirmBatch - Exception:', error);
            this.showToast('Error', 'Failed to start batch: ' + error.body?.message, 'error');
        } finally {
            this.isStartingBatch = false;
        }
    }

    // Polling
    startPolling() {
        console.log('startPolling - Starting batch status polling');
        this.stopPolling();
        this.pollingInterval = setInterval(() => {
            this.checkBatchStatus();
        }, 5000); // Poll every 5 seconds
    }

    stopPolling() {
        if (this.pollingInterval) {
            console.log('stopPolling - Stopping batch status polling');
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
        }
    }

    async checkBatchStatus() {
        if (!this.batchId) return;

        try {
            const result = await getBatchStatus({ batchId: this.batchId });
            console.log('checkBatchStatus - Status:', result);
            this.batchStatus = result;

            if (result?.isCompleted) {
                this.isBatchRunning = false;
                this.stopPolling();
                console.log('checkBatchStatus - Batch completed with status:', result.status);

                if (result.status === 'Completed' && result.numberOfErrors === 0) {
                    this.showToast('Success', 'Batch completed successfully!', 'success');
                    // Automatically load user stories when batch completes
                    this.showUserStoryList = true;
                    this.loadUserStories();
                    this.loadBatchSummary();
                } else if (result.status === 'Failed') {
                    this.showToast('Error', 'Batch failed: ' + result.extendedStatus, 'error');
                } else if (result.status === 'Aborted') {
                    this.showToast('Warning', 'Batch was aborted', 'warning');
                }
            }
        } catch (error) {
            console.error('checkBatchStatus - Error:', error);
        }
    }

    async handleRefreshStatus() {
        console.log('handleRefreshStatus - Manually refreshing batch status');
        await this.checkBatchStatus();
    }

    // User Story List Methods
    async loadUserStories() {
        if (!this.batchConfigJson) {
            console.warn('loadUserStories - No batch config available');
            return;
        }

        console.log('loadUserStories - Loading page:', this.currentPage);
        this.isLoadingUserStories = true;

        try {
            const offset = (this.currentPage - 1) * this.pageSize;
            console.log('loadUserStories - Offset:', offset, 'Limit:', this.pageSize);

            const result = await getUserStoriesCreatedByBatch({
                configJson: this.batchConfigJson,
                batchId: this.batchId,
                limitRecords: this.pageSize,
                offsetRecords: offset
            });

            console.log('loadUserStories - Result:', result);

            if (result.success) {
                this.totalUserStoriesCount = result.totalCount;

                // Format user stories for display
                this.userStories = result.userStories.map(us => {
                    return {
                        ...us,
                        userStoryUrl: `/${us.id}`,
                        progressClass: this.getProgressClass(us.progress)
                    };
                });
                console.log('loadUserStories - Loaded', this.userStories.length, 'user stories');
            } else {
                console.error('loadUserStories - Failed:', result.errorMessage);
                this.showToast('Error', result.errorMessage, 'error');
            }
        } catch (error) {
            console.error('loadUserStories - Exception:', error);
            this.showToast('Error', 'Failed to load user stories: ' + error.body?.message, 'error');
        } finally {
            this.isLoadingUserStories = false;
        }
    }

    async loadBatchSummary() {
        if (!this.batchConfigJson) {
            return;
        }

        console.log('loadBatchSummary - Loading summary');
        try {
            const result = await getBatchCreationSummary({
                configJson: this.batchConfigJson
            });

            console.log('loadBatchSummary - Result:', result);

            if (result.success) {
                this.batchSummary = result;
            }
        } catch (error) {
            console.error('loadBatchSummary - Error:', error);
        }
    }

    getProgressClass(progress) {
        if (!progress) return 'slds-text-color_weak';
        if (progress >= 100) return 'slds-text-color_success';
        if (progress >= 50) return 'slds-text-color_default';
        return 'slds-text-color_weak';
    }

    handleToggleUserStoryList() {
        this.showUserStoryList = !this.showUserStoryList;
        console.log('handleToggleUserStoryList - showUserStoryList:', this.showUserStoryList);

        if (this.showUserStoryList && this.userStories.length === 0) {
            this.loadUserStories();
            this.loadBatchSummary();
        }
    }

    handleRefreshUserStories() {
        console.log('handleRefreshUserStories - Refreshing user stories');
        this.currentPage = 1;
        this.loadUserStories();
        this.loadBatchSummary();
    }

    // Pagination handlers
    handleFirstPage() {
        console.log('handleFirstPage - Going to first page');
        this.currentPage = 1;
        this.loadUserStories();
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            console.log('handlePreviousPage - Going to page:', this.currentPage);
            this.loadUserStories();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            console.log('handleNextPage - Going to page:', this.currentPage);
            this.loadUserStories();
        }
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        console.log('handleLastPage - Going to last page:', this.currentPage);
        this.loadUserStories();
    }

    handleUserStoryRowAction(event) {
        const userStoryId = event.detail.row.id;
        console.log('handleUserStoryRowAction - Navigating to user story:', userStoryId);
        this.navigateToUserStory(userStoryId);
    }

    navigateToUserStory(userStoryId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: userStoryId,
                objectApiName: 'copado__User_Story__c',
                actionName: 'view'
            }
        });
    }

    // Utility
    showToast(title, message, variant) {
        console.log('showToast -', variant.toUpperCase(), ':', title, '-', message);
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}
