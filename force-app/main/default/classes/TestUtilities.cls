@SuppressWarnings('PMD.ExcessivePublicCount, PMD.CyclomaticComplexity')
@IsTest
public with sharing class TestUtilities {
    // PUBLIC

    public static void setup() {
        User runAsUser = createUser();
        assignPermissionSet(runAsUser.Id);
        System.runAs(runAsUser) {
            assignLicense(runAsUser.Id);
        }
    }

    public static void setupAdminUser(String username) {
        User runAsUser = createAdminUser(username);
        assignPermissionSet(runAsUser.Id);
        System.runAs(runAsUser) {
            assignLicense(runAsUser.Id);
        }
    }

    public static User createAdminUser(String username) {
        User runAsUser = new User(
            LastName = 'UserLastName-admin',
            Username = username,
            Email = username,
            Alias = 'MyAlias',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = getProfile('System Administrator').Id,
            LanguageLocaleKey = 'en_US'
        );
        insert runAsUser;
        return runAsUser;
    }

    public static User createUser() {
        return createUser( true );
    }

    public static User createUser( Boolean toInsert ) {
        User runAsUser = new User(
            LastName = 'UserLastName',
            Username = 'username@myemail.com',
            Email = 'username@myemail.com',
            Alias = 'MyAlias',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = getProfile('Standard User').Id,
            LanguageLocaleKey = 'en_US'
        );

        if ( toInsert ) {
            insert runAsUser;
        }

        return runAsUser;
    }

    private static Profile getProfile(String name) {
        return [SELECT Id, Name FROM Profile WHERE Name = :name];
    }

    public static User getRunAsUser() {
        List<User> runAsUsers = [SELECT Id, Username FROM User WHERE Username = 'username@myemail.com'];
        return runAsUsers[0];
    }

    public static User getRunAsUser(String username) {
        List<User> runAsUsers = [SELECT Id, Username FROM User WHERE Username = :username];
        return runAsUsers[0];
    }

    public static void assignLicense(Id userId) {
        copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
        copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
        userLicense.isCCMEnabled = true;
        userLicense.isCopadoEnabled = true;
        userLicense.userId = userId;
        copadoGlobalAPI.upsertCopadoLicense(userLicense);
    }

      public static void assignPermissionSet(Id userId) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

        Set<String> permissions = new Set<String>{
            'Copado_User',
            'Copado_Functions',
            'Copado_Job_Engine',
            'CMC_SFDX_Admin',
            'Configure_Snapshot',
            'Configure_AQF'
        };

        for (PermissionSet permission : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permissions]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permission.Id));
        }
        insert assignments;
    }

    public static List<copado__Org__c> createOrgCredentials(Integer count, String userName, List<copado__Environment__c> environments) {
        List<copado__Org__c> credentials = new List<copado__Org__c>();
        for (Integer i = 0; i < count; i++) {
            copado__Org__c org = new copado__Org__c();
            org.Name = 'Test Org ' + i;
            org.copado__Org_Type__c = 'Production/Developer';
            org.copado__Username__c = userName + i;
            org.copado__Environment__c = environments[i].Id;
            org.copado__Oauth_Signature__c = 'signature';
            org.copado__Validated_Date__c = System.now();

            credentials.add(org);
        }

        insert credentials;

        return credentials;
    }

    public static copado__Org__c createCredential(String name, String userName, Id environmentId, String orgType) {
        return new copado__Org__c(
            Name = name,
            copado__Org_Type__c = orgType,
            copado__Username__c = userName,
            copado__Environment__c = environmentId,
            copado__Oauth_Signature__c = 'signature',
            copado__Validated_Date__c = System.now()
        );
    }
       
}