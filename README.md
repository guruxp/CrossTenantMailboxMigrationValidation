# :warning: **IMPORTANT**: This script is no longer mantained here, and has been moved to the [Microsoft CSS-Exchange official repository](https://microsoft.github.io/CSS-Exchange/) direct link to this script: https://aka.ms/CrossTenantMailboxMigrationValidationScript

#
#
#

# CrossTenantMailboxMigrationValidation

## DESCRIPTION

This script offers the ability to validate users and org settings related to the Cross-tenant mailbox migration before creating a migration batch and have a better experience.

It will help you on:
- Making sure the source mailbox object is a member of the Mail-Enabled Security Group defined on the MailboxMovePublishedScopes of the source organization relationship
- Making sure the source mailbox object ExchangeGuid attribute value matches the one from the target MailUser object, and give you the option to set it
- Making sure the source mailbox object ArchiveGuid attribute (if there's an Archive enabled) value matches the one from the target MailUser object, and give you the option to set it
- Making sure the source mailbox object has no more than 12 auxArchives
- Making sure the source mailbox object has no hold applied
- Making sure the source mailbox object TotalDeletedItemsSize is not bigger than Target MailUser recoverable items size
- Making sure the source mailbox object LegacyExchangeDN attribute value is present on the target MailUser object as an X500 proxyAddress, and give you the option to set it, as long as the Target MailUser is not DirSynced
- Making sure the target MailUser object PrimarySMTPAddress attribute value is part of the target tenant accepted domains and give you the option to set it to be like the UPN if not true, as long as the Target MailUser is not DirSynced
- Making sure the target MailUser object EmailAddresses are all part of the target tenant accepted domains and give you the option to remove them if any doesn't belong to are found, as long as the Target MailUser is not DirSynced
- Making sure the target MailUser object ExternalEmailAddress attribute value points to the source Mailbox object PrimarySMTPAddress and give you the option to set it if not true, as long as the Target MailUser is not DirSynced
- Checking if there's an AAD app as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-destination-tenant-by-creating-the-migration-application-and-secret
- Checking if the target tenant has an Organization Relationship as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-tenant-by-creating-the-exchange-online-migration-endpoint-and-organization-relationship
- Checking if the target tenant has a Migration Endpoint as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-tenant-by-creating-the-exchange-online-migration-endpoint-and-organization-relationship
- Checking if the source tenant has an Organization Relationship as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-source-current-mailbox-location-tenant-by-accepting-the-migration-application-and-configuring-the-organization-relationship including a Mail-Enabled security group defined on the MailboxMovePublishedScopes property.
- Gather all the necessary information for troubleshooting and send it to Microsoft Support if needed
- Because not all scenarios allow access to both tenants by the same person, this will also allow you to collect the source tenant and mailbox information and wrap it into a zip file so the target tenant admin can use it as a source to validate against.

The script will prompt you to connect to your source and target tenants for EXO and AAD as needed
You can decide to run the checks for the source mailbox and target mailuser (individually or by providing a CSV file), for the organization settings described above, collect the source information and compress it to a zip file that can be used by the target tenant admins, or use the collected zip file as a source to validate the target objects and configurations against it.
    

### PRE-REQUISITES:

- Please make sure you have the Exchange Online V2 Powershell module (https://docs.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2?view=exchange-ps#install-and-maintain-the-exo-v2-module)
- You would need the Azure AD Module (https://docs.microsoft.com/en-us/powershell/azure/active-directory/install-adv2?view=azureadps-2.0#installing-the-azure-ad-module) 
- Also, depending on the parameters you specify, you will be prompted for the SourceTenantId and TargetTenantId (i.e.: if you choose to run the script with the "CheckOrgs" parameter). To obtain the tenant ID of a subscription, sign in to the Microsoft 365 admin center and go to https://aad.portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/Properties. Click the copy icon for the Tenant ID property to copy it to the clipboard.

## PARAMETERS

### CheckObjects
This will allow you to perform the checks for the Source Mailbox and Target MailUser objects you provide. If used without the "-CSV" parameter, you will be prompted to type the identities.

### CSV
This will allow you to specify a path for a CSV file you have with a list of users that contain the "SourceUser, TargetUser" columns.
An example of the CSV file content would be:

        SourceUser, TargetUser
        Jdoe@contoso.com, Jdoe@fabrikam.com
        BSmith@contoso.com, BSmith@fabrikam.com
        
If Used along with the 'CollectSourceOnly' parameter, you only need the 'SourceUser' column.

### CheckOrgs
This will allow you to perform the checks for the source and target organizations. More specifically the organization relationship on both tenants, the migration endpoint on target tenant and the existence of the AAD application needed.

### SDP
This will collect all the relevant information for troubleshooting from both tenants and be able to send it to Microsoft Support in case of needed.  

### LogPath
This will allow you to specify a log path to transcript all the script execution and it's results. This parameter is mandatory.

### CollectSourceOnly
This will allow you to specify a CSV file so we can export all necessary data of the source tenant and mailboxes to migrate, compress the files as a zip file to be used by the target tenant admin as a source for validation against the target. This parameter is mandatory and also requires the '-CSV' parameter to be specified containing the SourceUser column.

### PathForCollectedData
This will allow you to specify a path to store the exported data from the source tenant when used along with the 'CollectSourceOnly' and 'SDP' parameters transcript all the script execution and it's results. This parameter is mandatory.       

### SourceIsOffline
With this parameter, the script will only connect to target tenant and not source, instead it will rely on the zip file gathered when running this script along with the 'CollectSourceOnly' parameter. When used, you also need to specify the 'PathForCollectedData' parameter pointing to the collected zip file.


## EXAMPLES
### EXAMPLE 1

    .\CrossTenantMailboxMigrationValidation.ps1 -CheckObjects -LogPath C:\Temp\LogFile.txt

This will prompt you to type the source mailbox identity and the target identity, will establish 2 EXO remote powershell sessions (one to the source tenant and another one to the target tenant), and will check the objects.

### EXAMPLE 2
    
    .\CrossTenantMailboxMigrationValidation.ps1 -CheckObjects -CSV C:\Temp\UsersToMigrateValidationList.CSV -LogPath C:\Temp\LogFile.txt
    
This will establish 2 EXO remote powershell sessions (one to the source tenant and another one to the target tenant), will import the CSV file contents and will check the objects one by one.


### EXAMPLE 3    
    
    .\CrossTenantMailboxMigrationValidation.ps1 -CheckOrgs -LogPath C:\Temp\LogFile.txt
    
This will prompt you for the soureTenantId and TargetTenantId, establish 3 remote powershell sessions (one to the source EXO tenant, one to the target EXO tenant and another one to AAD target tenant), and will validate the migration endpoint on the target tenant, AAD applicationId on target tenant and the Orgnization relationship on both tenants.

### EXAMPLE 4

   
    .\CrossTenantMailboxMigrationValidation.ps1 -SDP -LogPath C:\Temp\LogFile.txt
    
This will prompt you for the soureTenantId and TargetTenantId, establish 3 remote powershell sessions (one to the source EXO tenant, one to the target EXO tenant and another one to AAD target tenant), and will collect all the relevant information (config-wise) so it can be used for troubleshooting and send it to Microsoft Support if needed.

### EXAMPLE 5
    .\CrossTenantMailboxMigrationValidation.ps1 -SourceIsOffline -PathForCollectedData C:\temp\CTMMCollectedSourceData.zip -CheckObjects -LogPath C:\temp\CTMMTarget.log

This will expand the CTMMCollectedSourceData.zip file contents into a folder with the same name within the zip location, will establish the EXO remote powershell session and also with AAD against the Target tenant and will check the objects contained on the UsersToProcess.CSV file.

### EXAMPLE 6
    .\CrossTenantMailboxMigrationValidation.ps1 -SourceIsOffline -PathForCollectedData C:\temp\CTMMCollectedSourceData.zip -CheckOrgs -LogPath C:\temp\CTMMTarget.log

This will expand the CTMMCollectedSourceData.zip file contents into a folder with the same name within the zip location, will establish the EXO remote powershell session and also with AAD against the Target tenant, and will validate the migration endpoint on the target tenant, AAD applicationId on target tenant and the Orgnization relationship on both tenants.

### EXAMPLE 7
    .\CrossTenantMailboxMigrationValidation.ps1 -CollectSourceOnly -PathForCollectedData c:\temp -LogPath C:\temp\CTMMCollectSource.log -CSV C:\temp\UsersToMigrate.csv

This will connect to the Source tenant against AAD and EXO, and will collect all the relevant information (config and user wise) so it can be used passed to the Target tenant admin for the Target validation to be done without the need to connect to the source tenant at the same time.


## NOTES

|     |     |
| --- | --- |
| File Name | CrossTenantMailboxMigrationValidation.ps1 |
| Version | 3.0 | 
| Author | Alberto Pascual Montoya (Microsoft) |  
| Contributors | Ignacio Serrano Acero (Microsoft) |  
| Requires | Exchange Online PowerShell V2 Module, AzureAD Module |  
| Created | 2022-03-17 |  
| Updated | 2022-11-28 |
|     |     |

## Disclaimer
THIS CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND. MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK ARISING OUT OF THE USE OR PERFORMANCE OF THE SAMPLES REMAINS WITH YOU. IN NO EVENT SHALL MICROSOFT OR ITS SUPPLIERS BE LIABLE FOR ANY DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR INABILITY TO USE THE SAMPLES, EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. BECAUSE SOME STATES DO NOT ALLOW THE EXCLUSION OR LIMITATION OF LIABILITY FOR CONSEQUENTIAL OR INCIDENTAL DAMAGES, THE ABOVE LIMITATION MAY NOT APPLY TO YOU.
