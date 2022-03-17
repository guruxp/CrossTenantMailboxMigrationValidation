<# 
.SYNOPSIS
    This script offers the ability to validate users and org settings related to the Cross-tenant mailbox migration before creating a migration batch and have a better experience.

.DESCRIPTION

    This script is intended to be used for:
    - Making sure the source mailbox object ExchangeGuid attribute value matches the one from the target MailUser object
    - Making sure the source mailbox object ArchiveGuid attribute (if there's an Archive enabled) value matches the one from the target MailUser object
    - Making sure the source mailbox object LegacyExchangeDN attribute value is present on the target MailUser object as an X500 proxyAddress
    - Making sure the target MailUser object PrimarySMTPAddress attribute value is part of the target tenant accepted domains and give you the option to set it to be like the UPN if not true
    - Making sure the target MailUser object EmailAddresses are all part of the target tenant accepted domains and give you the option to remove them if any doesn't belong to are found 
    - Making sure the target MailUser object ExternalEmailAddress attribute value points to the source Mailbox object PrimarySMTPAddress and give you the option to set it if not true
    - Checking if there's an AAD app as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-destination-tenant-by-creating-the-migration-application-and-secret 
    - Checking if the target tenant has an Organization Relationship as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-tenant-by-creating-the-exchange-online-migration-endpoint-and-organization-relationship
    - Checking if the target tenant has a Migration Endpoint as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-tenant-by-creating-the-exchange-online-migration-endpoint-and-organization-relationship
    - Checking if the source tenant has an Organization Relationship as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-source-current-mailbox-location-tenant-by-accepting-the-migration-application-and-configuring-the-organization-relationship

    The script will prompt you to connect to your source and target tenants for EXO and AAD (only if you specify the "CheckOrgs" parameter) 
    You can decide to run the checks for the source mailbox and target mailuser (individually or by providing a CSV file), or for the organization settings described above.

    PRE-REQUISITES:

    -Please make sure you have the Exchange Online V2 Powershell module (https://docs.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2?view=exchange-ps#install-and-maintain-the-exo-v2-module)
    -You would need the Azure AD Module (https://docs.microsoft.com/en-us/powershell/azure/active-directory/install-adv2?view=azureadps-2.0#installing-the-azure-ad-module)    
    -Also, you will be prompted for the SourceTenantId and TargetTenantId if you choose to run the script with the "CheckOrgs" parameter. To obtain the tenant ID of a subscription, sign in to the Microsoft 365 admin center and go to https://aad.portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/Properties. Click the copy icon for the Tenant ID property to copy it to the clipboard.

.PARAMETER CheckObjects
        This will allow you to perform the checks for the Source Mailbox and Target MailUser objects you provide. If used without the "-CSV" parameter, you will be prompted to type the identities.

.PARAMETER CSV
        This will allow you to specify a path for a CSV file you have with a list of users that contain the "SourceUser, TargetUser" columns.
        An example of the CSV file content would be:

        SourceUser, TargetUser
        Jdoe@contoso.com, Jdoe@fabrikam.com
        BSmith@contoso.com, BSmith@fabrikam.com

.PARAMETER CheckOrgs
        This will allow you to perform the checks for the source and target organizations. More specifically the organization relationship on both tenants, the migration endpoint on target tenant and the existence of the AAD application needed.
    

.EXAMPLE

        .\CrossTenantMailboxMigrationValidation.ps1 -CheckObjects

        This will prompt you to type the source mailbox identity and the target identity, will establish 2 EXO remote powershell sessions (one to the source tenant and another one to the target tenant), and will check the objects.

.EXAMPLE
    
        .\CrossTenantMailboxMigrationValidation.ps1 -CheckObjects -CSV C:\Temp\UsersToMigrateValidationList.CSV
    
        This will establish 2 EXO remote powershell sessions (one to the source tenant and another one to the target tenant), will import the CSV file contents and will check the objects one by one.

.EXAMPLE    
    
        .\CrossTenantMailboxMigrationValidation.ps1 -CheckOrgs
    
        This will prompt you for the soureTenantId and TargetTenantId, establish 3 remote powershell sessions (one to the source EXO tenant, one to the target EXO tenant and another one to AAD target tenant), and will validate the migration endpoint on the target tenant, AAD applicationId on target tenant and the Orgnization relationship on both tenants.


.NOTES
    File Name         : CrossTenantMailboxMigrationValidation.ps1
	Version           : 1.0
    Author            : Alberto Pascual Montoya (Microsoft)
	Contributors      : Ignacio Serrano Acero (Microsoft)
	Requires          : Exchange Online PowerShell V2 Module, AzureAD Module
	Created           : 2022-03-17
	Updated           : 2022-03-17
	Disclaimer        : THIS CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND. MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK ARISING OUT OF THE USE OR PERFORMANCE OF THE SAMPLES REMAINS WITH YOU. IN NO EVENT SHALL MICROSOFT OR ITS SUPPLIERS BE LIABLE FOR ANY DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR INABILITY TO USE THE SAMPLES, EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. BECAUSE SOME STATES DO NOT ALLOW THE EXCLUSION OR LIMITATION OF LIABILITY FOR CONSEQUENTIAL OR INCIDENTAL DAMAGES, THE ABOVE LIMITATION MAY NOT APPLY TO YOU.
#>

param (
    [Parameter(Mandatory=$True, ParameterSetName="ObjectsValidation", HelpMessage="Validate source Mailbox and Target MailUser objects. If used alone you will be prompted to introduce the identities you want to validate")]
    [System.Management.Automation.SwitchParameter]$CheckObjects,
    [Parameter(Mandatory=$False, ParameterSetName="ObjectsValidation", HelpMessage="Path pointing to the CSV containing the identities to validate. CheckObjects parameter needs also to be specified")]
    [System.String[]]$CSV, 
    [Parameter(Mandatory=$True, ParameterSetName="OrgsValidation", HelpMessage="Validate source Mailbox and Target MailUser objects. If used alone you will be prompted to introduce the identities you want to validate")]
    [System.Management.Automation.SwitchParameter]$CheckOrgs
)

$wsh = New-Object -ComObject Wscript.Shell

function ConnectToEXOTenants {
    #Connect to SourceTenant (EXO)
    Write-Host "Informational: Connecting to SOURCE EXO tenant"  -ForegroundColor Yellow
    $wsh.Popup("You're about to connect to source tenant (EXO), please provide the SOURCE tenant admin credentials", 0, "SOURCE tenant")
    Connect-ExchangeOnline -Prefix Source -ShowBanner:$false

    #Connect to TargetTenant (EXO)
    Write-Host "Informational: Connecting to TARGET EXO tenant"  -ForegroundColor Yellow
    $wsh.Popup("You're about to connect to target tenant (EXO), please provide the TARGET tenant admin credentials", 0, "TARGET tenant")
    Connect-ExchangeOnline -Prefix Target -ShowBanner:$false
}

function CheckObjects {
    
    Write-Host "Informational: Loading SOURCE object"$SourceIdentity -ForegroundColor Yellow
    $SourceObject = Get-SourceMailbox $SourceIdentity
    Write-Host "Informational: Loading TARGET object"$TargetIdentity  -ForegroundColor Yellow
    $TargetObject = Get-TargetMailUser $TargetIdentity

    #Verify ExchangeGuid on target object matches with source object and provide the option to set it in case it doesn't
    If (($SourceObject.ExchangeGuid -eq $null) -or ($TargetObject.ExchangeGuid -eq $null)) {
        Exit
    }
    Write-Host "Informational: Checking ExchangeGUID"  -ForegroundColor Yellow
    If ($SourceObject.ExchangeGuid -eq $TargetObject.ExchangeGuid) {
        Write-Host ">> ExchangeGuid match ok" -ForegroundColor Green
    }
    Else {
        Write-Host ">> Error: ExchangeGuid mismatch. Expected Vaue:" $SourceObject.ExchangeGuid ",Current value:" $TargetObject.ExchangeGuid -ForegroundColor Red
        $ExchangeGuidSetOption = Read-Host "Would you like to set it? (Y/N)"
        If ($ExchangeGuidSetOption.ToLower() -eq "y") {
            Write-Host "Informational: Setting correct ExchangeGUID on TARGET object"  -ForegroundColor Yellow
            Set-TargetMailUser $TargetIdentity -ExchangeGuid $SourceObject.ExchangeGuid
            #Reload TARGET object into variable as it has been changed
            $TargetObject = Get-TargetMailUser $TargetIdentity
        }
    }

    #Verify if Archive is present on source and if it is, verify ArchiveGuid on target object matches with source object and provide the option to set it in case it doesn't
    Write-Host "Informational: Checking if there's an Archive enabled on SOURCE object"  -ForegroundColor Yellow
    If ($SourceObject.ArchiveGUID -eq $null) {
        Exit
    }
    If ($SourceObject.ArchiveGuid -ne "00000000-0000-0000-0000-000000000000") {
        Write-Host "Informational: Archive is enabled on SOURCE object"  -ForegroundColor Yellow
        Write-Host "Informational: Checking ArchiveGUID"  -ForegroundColor Yellow
        If ($SourceObject.ArchiveGuid -eq $TargetObject.ArchiveGuid) {
            Write-Host ">> ArchiveGuid match ok" -ForegroundColor Green
        } 
        Else {
            Write-Host ">> Error: ArchiveGuid mismatch. Expected Value: "$SourceObject.ArchiveGuid", Current value: " $TargetObject.ArchiveGuid -ForegroundColor Red
            $ArchiveGuidSetOption = Read-Host "Would you like to set it? (Y/N)"
            If ($ArchiveGuidSetOption.ToLower() -eq "y") {
                Write-Host "Informational: Setting correct ArchiveGUID on TARGET object"  -ForegroundColor Yellow
                Set-TargetMailUser $TargetIdentity -ArchiveGuid $SourceObject.ArchiveGuid
                #Reload TARGET object into variable as it has been changed
                $TargetObject = Get-TargetMailUser $TargetIdentity
            }
        }
    }
    Else {
        Write-Host "Informational: Source object has no Archive enabled" -ForegroundColor Yellow
    }

    #Verify LagacyExchangeDN is present on target object as an X500 proxy address and provide the option to add it in case it isn't
    Write-Host "Informational: Checking if LegaxyExchangeDN from SOURCE object is part of EmailAddresses on TARGET object"  -ForegroundColor Yellow
    If ($TargetObject.EmailAddresses -eq $null) {
        Exit
    }
    If ($TargetObject.EmailAddresses -contains "X500:" + $SourceObject.LegacyExchangeDN) {
        Write-Host ">> LegacyExchangeDN found as an X500 ProxyAddress on Target Object." -ForegroundColor Green
    }
    Else {
        Write-Host ">> Error: LegacyExchangeDN not found as an X500 ProxyAddress on Target Object. LegacyExchangeDN expected on target object:" $SourceObject.LegacyExchangeDN -ForegroundColor Red
        $LegDNAddOption = Read-Host "Would you like to add it? (Y/N)"
        If ($LegDNAddOption.ToLower() -eq "y") {
            Write-Host "Informational: Adding LegacyExchangeDN as a proxyAddress on TARGET object"  -ForegroundColor Yellow
            Set-TargetMailUser $TargetIdentity -EmailAddresses @{Add = "X500:" + $SourceObject.LegacyExchangeDN }
            #Reload TARGET object into variable as it has been changed
            $TargetObject = Get-TargetMailUser $TargetIdentity  
        }
    }

    #Check if the primarySMTPAddress of the target MailUser is part of the accepted domains on the target tenant and if any of the email addresses of the target MailUser doesn't belong to the target accepted domains
    Write-Host "Informational: Loading TARGET accepted domains"  -ForegroundColor Yellow
    $TargetTenantAcceptedDomains = Get-TargetAcceptedDomain
    #PrimarySMTP
    Write-Host "Informational: Checking if the PrimarySTMPAddress of TARGET belongs to a TARGET accepted domain"  -ForegroundColor Yellow
    if ($TargetTenantAcceptedDomains.DomainName -notcontains $TargetObject.PrimarySmtpAddress.Split('@')[1]) {
        Write-Host ">> Error: The Primary SMTP address"$TargetObject.PrimarySmtpAddress"of the MailUser does not belong to an accepted domain on the target tenant, would you like to set it to"$TargetObject.UserPrincipalName"(Y/N): " -ForegroundColor Red -NoNewline
        $PrimarySMTPAddressSetOption = Read-Host
        if ($PrimarySMTPAddressSetOption.ToLower() -eq "y") {
            Write-Host "Informational: Setting the UserPrincipalName of TARGET object as the PrimarySMTPAddress"  -ForegroundColor Yellow
            Set-TargetMailUser $TargetIdentity -PrimarySmtpAddress $TargetObject.UserPrincipalName
            #Reload TARGET object into variable as it has been changed
            $TargetObject = Get-TargetMailUser $TargetIdentity
        }
    }
    Else {
        Write-Host ">> Target MailUser PrimarySMTPAddress is part of target accepted domains" -ForegroundColor Green
    }

    #EMailAddresses
    Write-Host "Informational: Checking for EmailAddresses on TARGET object that are not on the TARGET accepted domains list"  -ForegroundColor Yellow
    foreach ($Address in $TargetObject.EmailAddresses) {
        if ($Address.StartsWith("SMTP:") -or $Address.StartsWith("smtp:")) {
            If ($TargetTenantAcceptedDomains.DomainName -notcontains $Address.Split("@")[1]) {
                write-host ">> Error:"$Address" is not part of your organization, would you like to remove it? (Y/N): " -ForegroundColor Red -NoNewline
                $RemoveAddressOption = Read-Host 
                If ($RemoveAddressOption.ToLower() -eq "y") {
                    Write-Host "Informational: Removing the EmailAddress"$Address" from the TARGET object"  -ForegroundColor Yellow
                    Set-TargetMailUser $TargetIdentity -EmailAddresses @{Remove = $Address }
                    #Reload TARGET object into variable as it has been changed
                    $TargetObject = Get-TargetMailUser $TargetIdentity                    
                }
            }
        }
        Else {
            Write-Host ">> Target MailUser ProxyAddresses are all part of the target organization" -ForegroundColor Green
        }
    }

    #Check ExternalEmailAddress on TargetMailUser with primarySMTPAddress from SourceMailbox:
    Write-Host "Informational: Checking if the ExternalEmailAddress on TARGET object points to the PrimarySMTPAddress of the SOURCE object"  -ForegroundColor Yellow
    if ($TargetObject.ExternalEmailAddress.Split(":")[1] -eq $SourceObject.PrimarySmtpAddress) {
        Write-Host ">> ExternalEmailAddress of Target MailUser is pointing to PrimarySMTPAddress of Source Mailbox" -ForegroundColor Green
    }
    Else {
        write-host ">> Error: TargetMailUser ExternalEmailAddress value"$TargetObject.ExternalEmailAddress"does not match the PrimarySMTPAddress of the SourceMailbox"$SourceObject.PrimarySmtpAddress", would you like to set it? (Y/N): " -ForegroundColor Red -NoNewline
        $RemoveAddressOption = Read-Host 
        If ($RemoveAddressOption.ToLower() -eq "y") {
            Write-Host "Informational: Setting the ExternalEmailAddress of SOURCE object to"$SourceObject.PrimarySmtpAddress  -ForegroundColor Yellow
            Set-TargetMailUser $TargetIdentity -ExternalEmailAddress $SourceObject.PrimarySmtpAddress
            #Reload TARGET object into variable as it has been changed
            $TargetObject = Get-TargetMailUser $TargetIdentity            
        }
    }
}

function CheckOrgs {

    #Connect to TargetTenant (AzureAD)
    Write-Host "Informational: Connecting to AAD on TARGET tenant"  -ForegroundColor Yellow
    $wsh.Popup("You're about to connect to target tenant (AAD), please provide the TARGET tenant admin credentials", 0, "TARGET tenant")
    Connect-AzureAD

    #Check if there's an AAD EXO app as expected and load it onto a variable
    Write-Host "Informational: Checking if there's already an AAD Application on TARGET tenant that meets the criteria"  -ForegroundColor Yellow
    $AADEXOAPP = Get-AzureADApplication | ? { ($_.ReplyUrls -eq "https://office.com") -and ($_.RequiredResourceAccess -like "*ResourceAppId: 00000002-0000-0ff1-ce00-000000000000*") }
    if ($AADEXOAPP) {
        Write-Host "AAD application for EXO has been found" -ForegroundColor Green
        Write-Host "Informational: Loading migration endpoints on TARGET tenant that meets the criteria"  -ForegroundColor Yellow
        if (Get-TargetMigrationEndpoint | ? { ($_.RemoteServer -eq "outlook.office.com") -and ($_.EndpointType -eq "ExchangeRemoteMove") -and ($_.ApplicationId -eq $AADEXOAPP.AppId) }) {
            Write-Host "Migration endpoint found and correctly set" -ForegroundColor Green
        }
        Else {
            Write-Host "ERROR: Expected Migration endpoint not found" -ForegroundColor Red
        }
    }
    Else {
        Write-Host "ERROR: No AAD application for EXO has been found" -ForegroundColor Red
    }

    #Check orgrelationship flags on source and target orgs
    Write-Host "Informational: Loading Organization Relationship on SOURCE tenant that meets the criteria"  -ForegroundColor Yellow
    $SourceTenantOrgRelationship = Get-SourceOrganizationRelationship | ? { $_.OauthApplicationId -eq $AADEXOAPP.AppId }
    Write-Host "Informational: Loading Organization Relationship on TARGET tenant that meets the criteria"  -ForegroundColor Yellow
    $TargetTenantOrgRelationship = Get-TargetOrganizationRelationship | ? { $_.DomainNames -contains $SourceTenantId }

    Write-Host "Informational: Checking TARGET tenant organization relationship"  -ForegroundColor Yellow
    if ($TargetTenantOrgRelationship) {
        Write-Host "Organization relationship on TARGET tenant DomainNames is correctly pointing to SourceTenantId" -ForegroundColor Green
        if ($TargetTenantOrgRelationship.MailboxMoveEnabled) {
        Write-Host "Organization relationship on TARGET tenant is enabled for moves" -ForegroundColor Green
        }
        else {
        Write-Host "ERROR: Organization relationship on TARGET tenant mailbox is not enabled for moves" -ForegroundColor Red
        }
        if ($TargetTenantOrgRelationship.MailboxMoveCapability -eq "Inbound") {
        Write-Host "Organization relationship on TARGET tenant MailboxMove is correctly set" -ForegroundColor Green
        }                
        else {
        Write-Host "ERROR: Organization relationship on TARGET tenant MailboxMove is not correctly set. The expected value is 'Inbound' and the current value is"$TargetTenantOrgRelationship.MailboxMoveCapability -ForegroundColor Red
        }
    }
    else {
        Write-Host "ERROR: No Organization relationship on TARGET tenant pointing to SourceTenantId has been found" -ForegroundColor Red
    }
        
            

    Write-Host "Informational: Checking SOURCE tenant organization relationship"  -ForegroundColor Yellow
    if ($SourceTenantOrgRelationship.MailboxMoveEnabled) {
        Write-Host "Organization relationship on SOURCE tenant is enabled for moves" -ForegroundColor Green
        if ($SourceTenantOrgRelationship.MailboxMoveCapability -eq "RemoteOutbound") {
            Write-Host "Organization relationship on SOURCE tenant MailboxMove is correctly set" -ForegroundColor Green
            if ($SourceTenantOrgRelationship.DomainNames -contains $TargetTenantId) {
                Write-Host "Organization relationship on SOURCE tenant DomainNames is correctly pointing to TargetTenantId" -ForegroundColor Green
            }
            else {
                Write-Host "ERROR: Organization relationship on SOURCE tenant DomainNames is not pointing to TargetTenantId" -ForegroundColor Red
                #    $SourceOrgRelationshipDomainNames = Read-Host "Would you like to set it correctly? (Y/N)"
                #    If ($SourceOrgRelationshipDomainNames.ToLower() -eq "y") {
                #        Write-Host "Informational: Setting SOURCE Organization Relationship DomainNames to:"$TargetTenantId -ForegroundColor Yellow
                #        Set-OganizationRelationShip $SourceTenantOrgRelationship.Identity -DomainNames $TargetTenantId
                #   }
            }
        }
                
        else {
            Write-Host "ERROR: Organization relationship on SOURCE tenant MailboxMove is not correctly set. The expected value is 'RemoteOutbound' and the current value is"$TargetTenantOrgRelationship.MailboxMoveCapability -ForegroundColor Red
        }
    }
    else {
        Write-Host "ERROR: Organization relationship on TARGET tenant mailbox is not enabled for moves" -ForegroundColor Red
    }
}

if ($CheckObjects) {
    if ($CSV) {
        $Objects = Import-Csv $CSV
        ConnectToEXOTenants
        foreach ($object in $Objects) {
            $SourceIdentity = $object.SourceUser
            $TargetIdentity = $object.TargetUser
            Write-Host $SourceIdentity" is being used as SOURCE object"
            Write-Host $TargetIdentity" is being used as TARGET object"
            CheckObjects
        }
    }
    else {
        $SourceIdentity = Read-Host "Please type the SOURCE object to check at: "
        $TargetIdentity = Read-Host "Please type the TARGET object to compare with: "
        ConnectToEXOTenants
        CheckObjects
    }
} 

if ($CheckOrgs) {
    $SourceTenantId = Read-Host "Please specify the SOURCE TenantId: "
    $TargetTenantId = Read-Host "Please specify the TARGET TenantId: "
    ConnectToEXOTenants
    CheckOrgs
}

