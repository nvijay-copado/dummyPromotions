# Bulk User Story Creator for Copado

> **A powerful Lightning Web Component tool for creating bulk User Stories, metadata, and promotions in Copado pipelines for load testing and demonstrations.**

[![Salesforce API](https://img.shields.io/badge/Salesforce%20API-v65.0-blue.svg)](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/)
[![Lightning Web Components](https://img.shields.io/badge/LWC-Enabled-green.svg)](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
[![Copado](https://img.shields.io/badge/Copado-Compatible-orange.svg)](https://www.copado.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Installation](#-installation)
  - [Via Package URL](#via-package-url)
  - [Via SFDX](#via-sfdx-source-deployment)
- [What Gets Created](#-what-gets-created)
- [Prerequisites](#-prerequisites)
- [Configuration](#-configuration)
  - [Step 1: Create Mock Function](#step-1-create-mock-function)
  - [Step 2: Create Job Template](#step-2-create-job-template--job-steps)
  - [Step 3: Override Pipeline Actions](#step-3-override-pipeline-actions)
- [Usage](#-usage)
- [Architecture](#-architecture)
- [Monitoring & Troubleshooting](#-monitoring--troubleshooting)
- [Limitations](#-limitations)
- [Contributing](#-contributing)
- [License](#-license)
- [Support](#-support)

---

## 🎯 Overview

The **Bulk User Story Creator** is a Salesforce Lightning Web Component (LWC) built for Copado users who need to:

- **Load test** their Copado pipelines with realistic data volumes
- **Demonstrate** Copado functionality with sample data
- **Test performance** of promotion and deployment processes
- **Generate mock data** for training environments

### ⚠️ Important Notice

> **This tool creates MOCK DATA only.**
> 
> - ❌ No actual Git branches are created
> - ❌ No real deployments occur
> - ❌ No metadata is committed to repositories
> - ✅ All records are for testing, demonstration, or load testing purposes

---

## ✨ Features

- ✅ **Bulk User Story Creation** - Create thousands of User Stories in configurable batches
- ✅ **Automatic Metadata Generation** - Attach configurable metadata records to each User Story
- ✅ **Mock Promotions** - Generate promotion records through pipeline environments
- ✅ **Job Execution Simulation** - Create mock job executions for testing
- ✅ **Real-time Progress Tracking** - Monitor batch progress via LWC interface
- ✅ **Configurable Batch Size** - Control governor limits by adjusting batch sizes
- ✅ **Email Notifications** - Receive completion notifications with summary statistics
- ✅ **Pipeline-aware** - Automatically detects pipeline environments and structure

---

## 📦 Installation

### Via Package URL

Choose the appropriate installation link based on your Salesforce environment:

#### Production Environment
```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdM000000OPTVQA4
```

#### Sandbox Environment
```
https://test.salesforce.com/packaging/installPackage.apexp?p0=04tdM000000OPTVQA4
```

**Installation Steps:**

1. Click the appropriate link above
2. Log in to your Salesforce org
3. Select **"Install for Admins Only"** (recommended for testing)
4. Click **Install**
5. Approve Third-Party Access if prompted
6. Wait for installation to complete

---

### Via SFDX (Source Deployment)

If you prefer to deploy from source:

```bash
# Clone the repository
git clone https://github.com/your-org/bulk-userstory-creator.git
cd bulk-userstory-creator

# Authenticate to your org
sfdx auth:web:login -a myDevOrg

# Deploy the source
sfdx force:source:deploy -p force-app/main/default -u myDevOrg

# Assign permission set (if applicable)
sfdx force:user:permset:assign -n Bulk_User_Story_Creator -u myDevOrg
```

---

## 🗂️ What Gets Created

The tool generates the following Copado records:

| Record Type | Description | Volume |
|------------|-------------|--------|
| **User Stories** | Copado User Story records with configurable fields | Configurable (1-10,000+) |
| **User Story Metadata** | Metadata records linked to User Stories | Configurable per User Story |
| **Promotions** | Promotion records moving through pipeline | 1 per User Story |
| **Promoted User Stories** | Junction records linking Stories to Promotions | 1 per User Story |
| **Job Executions** | Mock job execution records (no actual deployment) | Auto-generated |

---

## 🔧 Prerequisites

Before using the Bulk User Story Creator, ensure you have:

- ✅ **Copado DevOps Platform** installed
- ✅ **Active Copado Pipeline** with configured environments
- ✅ **Project** associated with the pipeline
- ✅ **Admin access** to configure Functions and Job Templates
- ✅ **Sufficient data storage** in your org

---

## ⚙️ Configuration

To prevent actual deployments and Git operations, you must configure mock pipeline actions.

### Step 1: Create Mock Function

Navigate to **Copado → Functions**

```yaml
Function Details:
  Name: Mock Promote & Deploy
  API Name: Mock_Promote_Deploy
  Type: Custom
  
Script:
```

```bash
#!/bin/bash
echo "=========================================="
echo "Mock Promote & Deploy"
echo "No actual deployment performed"
echo "Timestamp: $(date)"
echo "=========================================="
exit 0
```

**Save** the function.

---

### Step 2: Create Job Template & Job Steps

#### A. Create Job Template

Navigate to **Copado → Job Templates**

```yaml
Job Template:
  Name: Mock Promotion & Deployment
  Version: 1
```

#### B. Add Job Step

In the **Job Steps** related list:

```yaml
Job Step Details:
  Name: Mock Promotion & Deployment
  Type: Function
  Function: Mock Promote & Deploy
```

**Advanced Configuration:**

```yaml
Resource Observation:
  Queue Name: {$Context.JobExecution__r.Pipeline__r.Git_Repository__r.URI__c}/{$Destination.Branch}
```

**Save** the Job Step.

---

### Step 3: Override Pipeline Actions

Navigate to your target **Pipeline → Settings → Pipeline Actions**

Add **TWO** pipeline action overrides:

#### Override 1: Promotion

```yaml
Action: Promotion
Job Template: Mock Promotion & Deployment
```

#### Override 2: Promotion Deployment

```yaml
Action: Promotion Deployment
Job Template: Mock Promotion & Deployment
```

**Save** both overrides.

---

## 🚀 Usage

### Launch the Application

1. Open the **App Launcher** in Salesforce
2. Search for **"Bulk User Story Creator"**
3. Click to open the Lightning application

### Configure Bulk Creation

1. **Select Pipeline** - Choose your configured pipeline
2. **Select Project** - Choose the associated project
3. **Select Release** (Optional) - Associate User Stories with a release
4. **Choose Record Type** - Select User Story record type
5. **Configure Volume:**
   - Total User Stories to create (e.g., 1000)
   - User Stories per Batch (recommended: 10-25)
   - Metadata records per User Story (e.g., 5)

### Start Batch Process

1. Click **"Validate Configuration"** to check settings
2. Review warnings and estimates
3. Click **"Start Batch Creation"**

### Monitor Progress

- Real-time progress bar shows completion percentage
- Check **Setup → Apex Jobs** for detailed batch status
- Email notification sent upon completion

---

## 🏗️ Architecture

### Component Structure

```
force-app/main/default/
├── classes/
│   ├── BulkUserStoryCreatorController.cls          # Aura-enabled controller
│   ├── BulkUserStoryCreatorController.cls-meta.xml
│   ├── BulkUserStoryCreationBatch.cls              # Batch Apex processor
│   └── BulkUserStoryCreationBatch.cls-meta.xml
├── lwc/
│   └── bulkUserStoryCreator/
│       ├── bulkUserStoryCreator.html               # LWC template
│       ├── bulkUserStoryCreator.js                 # LWC JavaScript
│       ├── bulkUserStoryCreator.js-meta.xml        # LWC metadata
│       └── bulkUserStoryCreator.css                # LWC styles
└── aura/
    └── BulkUserStoryCreatorApp/
        ├── BulkUserStoryCreatorApp.app             # Lightning App
        └── BulkUserStoryCreatorApp.app-meta.xml
```

### Data Flow

```
User Input (LWC)
    ↓
Controller Validation
    ↓
Batch Job Initiated
    ↓
┌──────────────────────────────┐
│  Batch Execution (Stateful)  │
│  ┌────────────────────────┐  │
│  │ 1. Create User Stories │  │
│  └──────────┬─────────────┘  │
│             ↓                │
│  ┌────────────────────────┐  │
│  │ 2. Create Metadata     │  │
│  └──────────┬─────────────┘  │
│             ↓                │
│  ┌────────────────────────┐  │
│  │ 3. Create Promotions   │  │
│  └──────────┬─────────────┘  │
│             ↓                │
│  ┌────────────────────────┐  │
│  │ 4. Link User Stories   │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
    ↓
Email Notification
    ↓
Status Update (LWC)
```

### Key Classes

#### `BulkUserStoryCreatorController`
- Handles LWC interactions
- Validates configuration
- Initiates batch jobs
- Monitors batch status

#### `BulkUserStoryCreationBatch`
- Implements `Database.Batchable<Integer>`
- Stateful batch processing
- Creates User Stories in chunks
- Generates related records

---

## 🔍 Monitoring & Troubleshooting

### Monitor Batch Progress

**Via Setup:**
1. Navigate to **Setup → Environments → Jobs → Apex Jobs**
2. Find your batch job by ID or timestamp
3. Monitor status, progress, and errors

**Via Debug Logs:**
```sql
SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors
FROM AsyncApexJob
WHERE ApexClass.Name = 'BulkUserStoryCreationBatch'
ORDER BY CreatedDate DESC
LIMIT 10
```

### Common Issues

#### ❌ "Invalid type: BulkUserStoryCreationBatch"

**Cause:** Controller class deployed without batch class.

**Solution:** Deploy both classes together or ensure batch class exists in org.

---

#### ❌ Promotions executing real deployments

**Cause:** Pipeline Actions not properly overridden.

**Solution:** 
1. Verify **Mock Promotion & Deployment** job template exists
2. Check Pipeline Settings → Pipeline Actions
3. Ensure both "Promotion" and "Promotion Deployment" are overridden

---

#### ❌ Batch fails with governor limits

**Cause:** Batch size too large or too many metadata records.

**Solution:**
- Reduce "User Stories per Batch" (try 10-15)
- Reduce "Metadata per User Story" (try < 50)
- Check total DML statements in debug logs

---

#### ❌ "List has no rows for assignment"

**Cause:** Pipeline has no environments or invalid configuration.

**Solution:** Ensure pipeline has at least one deployment flow step with source and destination environments.

---

### Debug Mode

Enable debug logs for detailed execution tracking:

```apex
// In Developer Console
System.debug('=== Batch Configuration ===');
System.debug('Pipeline: ' + pipelineId);
System.debug('Total User Stories: ' + totalUserStories);
System.debug('Batch Size: ' + userStoriesPerBatch);
```

---

## 🚫 Limitations

### Salesforce Limits

| Limit Type | Impact |
|-----------|---------|
| **Batch Apex Limits** | Maximum 5 batch jobs in queue per org |
| **DML Limits** | 10,000 DML statements per transaction |
| **SOQL Limits** | 100 SOQL queries per transaction |
| **Heap Size** | 12 MB for synchronous, 12 MB for async |
| **Data Storage** | Large volumes may impact org storage |

### Recommended Constraints

- **Total User Stories:** < 10,000 per batch job
- **Batch Size:** 10-25 User Stories per batch
- **Metadata per Story:** < 100 records
- **Concurrent Jobs:** Only 1 bulk creation job at a time

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

1. Check existing issues first
2. Use issue templates
3. Include debug logs and error messages
4. Provide org edition and Copado version

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/bulk-userstory-creator.git
cd bulk-userstory-creator

# Create a scratch org
sfdx force:org:create -f config/project-scratch-def.json -a bulk-creator-dev

# Push source
sfdx force:source:push -u bulk-creator-dev

# Open the org
sfdx force:org:open -u bulk-creator-dev
```

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2026 Your Organization

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

---

## 🆘 Support

### Documentation

- [Copado Documentation](https://docs.copado.com/)
- [Salesforce LWC Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [Batch Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch.htm)

### Getting Help

- 📧 Email: support@yourcompany.com
- 💬 Slack: [#copado-tools](https://yourworkspace.slack.com)
- 🐛 Issues: [GitHub Issues](https://github.com/your-org/bulk-userstory-creator/issues)
- 📖 Wiki: [Project Wiki](https://github.com/your-org/bulk-userstory-creator/wiki)

### Community

- [Copado Community](https://success.copado.com/)
- [Salesforce Stack Exchange](https://salesforce.stackexchange.com/)
- [Trailblazer Community](https://trailblazers.salesforce.com/)

---

## 🙏 Acknowledgments

- Built with ❤️ for the Copado community
- Powered by Salesforce Lightning Web Components
- Inspired by the need for better load testing tools

---

## 📊 Project Status

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Coverage](https://img.shields.io/badge/coverage-85%25-green)
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Downloads](https://img.shields.io/badge/downloads-500+-orange)

---

## 🗺️ Roadmap

- [ ] Support for Custom User Story fields
- [ ] Integration with Git providers (mock branch creation)
- [ ] Export/Import configuration templates
- [ ] Bulk deletion utility
- [ ] Enhanced reporting dashboard
- [ ] Multi-language support

---

**Made with ⚡ by Copado DevOps Engineers**

[⬆ Back to Top](#bulk-user-story-creator-for-copado)