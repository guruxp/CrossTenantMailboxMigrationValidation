﻿<#
    MIT License

    Copyright (c) Microsoft Corporation.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE
#>

# Version 24.09.17.1810.NoSIG

#Requires -Version 5.1
#Requires -Modules ExchangeOnlineManagement, Microsoft.Graph.Applications

<#
.SYNOPSIS
    This script offers the ability to validate users and org settings related to the Cross-tenant mailbox migration before creating a migration batch and have a better experience.

.DESCRIPTION
    This script is intended to be used for:
    - Making sure the source mailbox object is a member of the Mail-Enabled Security Group defined on the MailboxMovePublishedScopes of the source organization relationship
    - Making sure the source mailbox object ExchangeGuid attribute value matches the one from the target MailUser object, and give you the option to set it
    - Making sure the source mailbox object ArchiveGuid attribute (if there's an Archive enabled) value matches the one from the target MailUser object, and give you the option to set it
    - Making sure the source mailbox object has no more than 12 auxArchives
    - Making sure the source mailbox object has no hold applied
    - Making sure the source mailbox object TotalDeletedItemsSize is not bigger than Target MailUser recoverable items size
    - Making sure the source mailbox object LegacyExchangeDN attribute value is present on the target MailUser object as an X500 proxyAddress, and give you the option to set it, as long as the Target MailUser is not DirSynced
    - Making sure the source mailbox object X500 addresses are also present on the target MailUser object.
    - Making sure the target MailUser object PrimarySMTPAddress attribute value is part of the target tenant accepted domains and give you the option to set it to be like the UPN if not true, as long as the Target MailUser is not DirSynced
    - Making sure the target MailUser object EmailAddresses are all part of the target tenant accepted domains and give you the option to remove them if any doesn't belong to are found, as long as the Target MailUser is not DirSynced
    - Making sure the target MailUser object ExternalEmailAddress attribute value points to the source Mailbox object PrimarySMTPAddress and give you the option to set it if not true, as long as the Target MailUser is not DirSynced
    - Verifying if there's a T2T license assigned on either the source or target objects.
    - Checking if there's an AAD app as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-destination-tenant-by-creating-the-migration-application-and-secret
    - Checking if the AAD app on Target has been consented in Source tenant as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-source-current-mailbox-location-tenant-by-accepting-the-migration-application-and-configuring-the-organization-relationship
    - Checking if the target tenant has an Organization Relationship as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-tenant-by-creating-the-exchange-online-migration-endpoint-and-organization-relationship
    - Checking if the target tenant has a Migration Endpoint as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-target-tenant-by-creating-the-exchange-online-migration-endpoint-and-organization-relationship
    - Checking if the source tenant has an Organization Relationship as described on https://docs.microsoft.com/en-us/microsoft-365/enterprise/cross-tenant-mailbox-migration?view=o365-worldwide#prepare-the-source-current-mailbox-location-tenant-by-accepting-the-migration-application-and-configuring-the-organization-relationship including a Mail-Enabled security group defined on the MailboxMovePublishedScopes property.
    - Gather all the necessary information for troubleshooting and send it to Microsoft Support if needed
    - Because not all scenarios allow access to both tenants by the same person, this will also allow you to collect the source tenant and mailbox information and wrap it into a zip file so the target tenant admin can use it as a source to validate against.

    The script will prompt you to connect to your source and target tenants for EXO and AAD as needed
    You can decide to run the checks for the source mailbox and target MailUser (individually or by providing a CSV file), for the organization settings described above, collect the source information and compress it to a zip file that can be used by the target tenant admins, or use the collected zip file as a source to validate the target objects and configurations against it.

    PRE-REQUISITES:
    -Please make sure you have at least the Exchange Online V2 Powershell module (https://docs.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2?view=exchange-ps#install-and-maintain-the-exo-v2-module)
    -You would need the Microsoft Graph PowerShell SDK Module (https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0)
    -Also, depending on the parameters you specify, you will be prompted for the SourceTenantId and TargetTenantId (i.e.: if you choose to run the script with the "CheckOrgs" parameter). To obtain the tenant ID of a subscription, sign in to the Microsoft 365 admin center and go to https://aad.portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/Properties. Click the copy icon for the Tenant ID property to copy it to the clipboard.

.PARAMETER SkipVersionCheck
        This will allow you to skip the version check and run the existing local version of the script. This parameter is optional.

.PARAMETER ScriptUpdateOnly
        This will allow you to check if there's a newer version available on CSS-Exchange repository without performing any additional checks, and will download it if so. This parameter is optional.

.PARAMETER CheckObjects
        This will allow you to perform the checks for the Source Mailbox and Target MailUser objects you provide. If used without the "-CSV" parameter, you will be prompted to type the identities.. If used with the '-SourceIsOffline' you also need to specify the '-PathForCollectedData' parameter

.PARAMETER CSV
        This will allow you to specify a path for a CSV file you have with a list of users that contain the "SourceUser, TargetUser" columns.
        An example of the CSV file content would be:
        SourceUser, TargetUser
        Jdoe@contoso.com, Jdoe@fabrikam.com
        BSmith@contoso.com, BSmith@fabrikam.com

        If Used along with the 'CollectSourceOnly' parameter, you only need the 'SourceUser' column.

.PARAMETER CheckOrgs
        This will allow you to perform the checks for the source and target organizations. More specifically the organization relationship on both tenants, the migration endpoint on target tenant and the existence of the AAD application needed.

.PARAMETER SDP
        This will collect all the relevant information for troubleshooting from both tenants and be able to send it to Microsoft Support in case of needed.

.PARAMETER LogPath
        This will allow you to specify a log path to transcript all the script execution and it's results. This parameter is mandatory.

.PARAMETER CollectSourceOnly
        This will allow you to specify a CSV file so we can export all necessary data of the source tenant and mailboxes to migrate, compress the files as a zip file to be used by the target tenant admin as a source for validation against the target. This parameter is mandatory and also requires the '-CSV' parameter to be specified containing the SourceUser column.

.PARAMETER PathForCollectedData
        This will allow you to specify a path to store the exported data from the source tenant when used along with the 'CollectSourceOnly' and 'SDP' parameters transcript all the script execution and it's results. This parameter is mandatory.

.PARAMETER SourceIsOffline
        With this parameter, the script will only connect to target tenant and not source, instead it will rely on the zip file gathered when running this script along with the 'CollectSourceOnly' parameter. When used, you also need to specify the 'PathForCollectedData' parameter pointing to the collected zip file.

.EXAMPLE
        .\CrossTenantMailboxMigrationValidation.ps1 -CheckObjects -LogPath C:\Temp\LogFile.txt
        This will prompt you to type the source mailbox identity and the target identity, will establish 2 EXO remote powershell sessions (one to the source tenant and another one to the target tenant), and will check the objects.

.EXAMPLE
        .\CrossTenantMailboxMigrationValidation.ps1 -CheckObjects -CSV C:\Temp\UsersToMigrateValidationList.CSV -LogPath C:\Temp\LogFile.txt
        This will establish 2 EXO remote powershell sessions (one to the source tenant and another one to the target tenant), will import the CSV file contents and will check the objects one by one.

.EXAMPLE
        .\CrossTenantMailboxMigrationValidation.ps1 -CheckOrgs -LogPath C:\Temp\LogFile.txt
        This will establish 4 remote powershell sessions (source and target EXO tenants, and source and target AAD tenants), and will validate the migration endpoint on the target tenant, AAD applicationId on target tenant and the Organization relationship on both tenants.

.EXAMPLE
        .\CrossTenantMailboxMigrationValidation.ps1 -SDP -LogPath C:\Temp\LogFile.txt -PathForCollectedData C:\temp
        This will establish 4 remote powershell sessions (source and target EXO tenants, and source and target AAD tenants), and will collect all the relevant information (config-wise) so it can be used for troubleshooting and send it to Microsoft Support if needed.

.EXAMPLE
        .\CrossTenantMailboxMigrationValidation.ps1 -SourceIsOffline -PathForCollectedData C:\temp\CTMMCollectedSourceData.zip -CheckObjects -LogPath C:\temp\CTMMTarget.log
        This will expand the CTMMCollectedSourceData.zip file contents into a folder with the same name within the zip location, will establish the EXO remote powershell session and also with AAD against the Target tenant and will check the objects contained on the UsersToProcess.CSV file.

.EXAMPLE
        .\CrossTenantMailboxMigrationValidation.ps1 -SourceIsOffline -PathForCollectedData C:\temp\CTMMCollectedSourceData.zip -CheckOrgs -LogPath C:\temp\CTMMTarget.log
        This will expand the CTMMCollectedSourceData.zip file contents into a folder with the same name within the zip location, will establish the EXO remote powershell session and also with AAD against the Target tenant, and will validate the migration endpoint on the target tenant, AAD applicationId on target tenant and the Organization relationship on both tenants.

.EXAMPLE
        .\CrossTenantMailboxMigrationValidation.ps1 -CollectSourceOnly -PathForCollectedData c:\temp -LogPath C:\temp\CTMMCollectSource.log -CSV C:\temp\UsersToMigrate.csv
        This will connect to the Source tenant against AAD and EXO, and will collect all the relevant information (config and user wise) so it can be used passed to the Target tenant admin for the Target validation to be done without the need to connect to the source tenant at the same time.
.#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('CustomRules\AvoidUsingReadHost', '', Justification = 'Do not want to change logic of script as of now')]
param (
    [Parameter(Mandatory = $True, ParameterSetName = "ObjectsValidation", HelpMessage = "Validate source Mailbox and Target MailUser objects. If used alone you will be prompted to introduce the identities you want to validate")]
    [Parameter(Mandatory = $False, ParameterSetName = "OfflineMode", HelpMessage = "Validate source Mailbox and Target MailUser objects. If used alone you will be prompted to introduce the identities you want to validate")]
    [System.Management.Automation.SwitchParameter]$CheckObjects,
    [Parameter(Mandatory = $False, ParameterSetName = "ObjectsValidation", HelpMessage = "Path pointing to the CSV containing the identities to validate. CheckObjects parameter needs also to be specified")]
    [Parameter(Mandatory = $True, ParameterSetName = "CollectMode", HelpMessage = "Path pointing to the CSV containing the identities to validate. CheckObjects parameter needs also to be specified")]
    [System.String]$CSV,
    [Parameter(Mandatory = $True, ParameterSetName = "ObjectsValidation", HelpMessage = "Path pointing to the log file")]
    [Parameter(Mandatory = $True, ParameterSetName = "OfflineMode", HelpMessage = "Path pointing to the log file")]
    [Parameter(Mandatory = $True, ParameterSetName = "CollectMode", HelpMessage = "Path pointing to the log file")]
    [Parameter(Mandatory = $True, ParameterSetName = "OrgsValidation", HelpMessage = "Path pointing to the log file")]
    [Parameter(Mandatory = $True, ParameterSetName = "SDP", HelpMessage = "Path pointing to the log file")]
    [System.String]$LogPath,
    [Parameter(Mandatory = $True, ParameterSetName = "OrgsValidation", HelpMessage = "Validate the organizations settings like organization relationships, migration endpoint and AADApplication")]
    [Parameter(Mandatory = $False, ParameterSetName = "OfflineMode", HelpMessage = "Validate the organizations settings like organization relationships, migration endpoint and AADApplication")]
    [System.Management.Automation.SwitchParameter]$CheckOrgs,
    [Parameter(Mandatory = $True, ParameterSetName = "SDP", HelpMessage = "Collect relevant data for troubleshooting purposes and send it to Microsoft Support if needed")]
    [System.Management.Automation.SwitchParameter]$SDP,
    [Parameter(Mandatory = $False, ParameterSetName = "CollectMode", HelpMessage = "Collect source only mode, to generate the necessary files and provide them to the target tenant admin. You need to specify the CSV parameter as well")]
    [System.Management.Automation.SwitchParameter]$CollectSourceOnly,
    [Parameter(Mandatory = $True, ParameterSetName = "SDP", HelpMessage = "Path that will be used to store the collected data")]
    [Parameter(Mandatory = $True, ParameterSetName = "CollectMode", HelpMessage = "Path that will be used to store the collected data")]
    [Parameter(Mandatory = $True, ParameterSetName = "OfflineMode", HelpMessage = "Path that will be used to store the collected data, you should specify the path and the zip file name")]
    [System.String]$PathForCollectedData,
    [Parameter(Mandatory = $false, ParameterSetName = "OfflineMode", HelpMessage = "Do not connect to source EXO tenant, but specify a zip file gathered when running the script with the 'CollectSourceOnly' parameter.")]
    [System.Management.Automation.SwitchParameter]$SourceIsOffline,
    [Parameter(Mandatory = $False, ParameterSetName = "ObjectsValidation")]
    [Parameter(Mandatory = $False, ParameterSetName = "OfflineMode")]
    [Parameter(Mandatory = $False, ParameterSetName = "CollectMode")]
    [Parameter(Mandatory = $False, ParameterSetName = "OrgsValidation")]
    [Parameter(Mandatory = $False, ParameterSetName = "SDP")]
    [switch]$SkipVersionCheck,
    [Parameter(Mandatory = $true, ParameterSetName = "ScriptUpdateOnly")]
    [switch]$ScriptUpdateOnly
)





function Confirm-ProxyServer {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $TargetUri
    )

    Write-Verbose "Calling $($MyInvocation.MyCommand)"
    try {
        $proxyObject = ([System.Net.WebRequest]::GetSystemWebProxy()).GetProxy($TargetUri)
        if ($TargetUri -ne $proxyObject.OriginalString) {
            Write-Verbose "Proxy server configuration detected"
            Write-Verbose $proxyObject.OriginalString
            return $true
        } else {
            Write-Verbose "No proxy server configuration detected"
            return $false
        }
    } catch {
        Write-Verbose "Unable to check for proxy server configuration"
        return $false
    }
}

function WriteErrorInformationBase {
    [CmdletBinding()]
    param(
        [object]$CurrentError = $Error[0],
        [ValidateSet("Write-Host", "Write-Verbose")]
        [string]$Cmdlet
    )

    if ($null -ne $CurrentError.OriginInfo) {
        & $Cmdlet "Error Origin Info: $($CurrentError.OriginInfo.ToString())"
    }

    & $Cmdlet "$($CurrentError.CategoryInfo.Activity) : $($CurrentError.ToString())"

    if ($null -ne $CurrentError.Exception -and
        $null -ne $CurrentError.Exception.StackTrace) {
        & $Cmdlet "Inner Exception: $($CurrentError.Exception.StackTrace)"
    } elseif ($null -ne $CurrentError.Exception) {
        & $Cmdlet "Inner Exception: $($CurrentError.Exception)"
    }

    if ($null -ne $CurrentError.InvocationInfo.PositionMessage) {
        & $Cmdlet "Position Message: $($CurrentError.InvocationInfo.PositionMessage)"
    }

    if ($null -ne $CurrentError.Exception.SerializedRemoteInvocationInfo.PositionMessage) {
        & $Cmdlet "Remote Position Message: $($CurrentError.Exception.SerializedRemoteInvocationInfo.PositionMessage)"
    }

    if ($null -ne $CurrentError.ScriptStackTrace) {
        & $Cmdlet "Script Stack: $($CurrentError.ScriptStackTrace)"
    }
}

function Write-VerboseErrorInformation {
    [CmdletBinding()]
    param(
        [object]$CurrentError = $Error[0]
    )
    WriteErrorInformationBase $CurrentError "Write-Verbose"
}

function Write-HostErrorInformation {
    [CmdletBinding()]
    param(
        [object]$CurrentError = $Error[0]
    )
    WriteErrorInformationBase $CurrentError "Write-Host"
}

function Invoke-WebRequestWithProxyDetection {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [string]
        $Uri,

        [Parameter(Mandatory = $false, ParameterSetName = "Default")]
        [switch]
        $UseBasicParsing,

        [Parameter(Mandatory = $true, ParameterSetName = "ParametersObject")]
        [hashtable]
        $ParametersObject,

        [Parameter(Mandatory = $false, ParameterSetName = "Default")]
        [string]
        $OutFile
    )

    Write-Verbose "Calling $($MyInvocation.MyCommand)"
    if ([System.String]::IsNullOrEmpty($Uri)) {
        $Uri = $ParametersObject.Uri
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (Confirm-ProxyServer -TargetUri $Uri) {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell")
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    }

    if ($null -eq $ParametersObject) {
        $params = @{
            Uri     = $Uri
            OutFile = $OutFile
        }

        if ($UseBasicParsing) {
            $params.UseBasicParsing = $true
        }
    } else {
        $params = $ParametersObject
    }

    try {
        Invoke-WebRequest @params
    } catch {
        Write-VerboseErrorInformation
    }
}

<#
    Determines if the script has an update available.
#>
function Get-ScriptUpdateAvailable {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $VersionsUrl = "https://github.com/microsoft/CSS-Exchange/releases/latest/download/ScriptVersions.csv"
    )

    $BuildVersion = "24.09.17.1810"

    $scriptName = $script:MyInvocation.MyCommand.Name
    $scriptPath = [IO.Path]::GetDirectoryName($script:MyInvocation.MyCommand.Path)
    $scriptFullName = (Join-Path $scriptPath $scriptName)

    $result = [PSCustomObject]@{
        ScriptName     = $scriptName
        CurrentVersion = $BuildVersion
        LatestVersion  = ""
        UpdateFound    = $false
        Error          = $null
    }

    if ((Get-AuthenticodeSignature -FilePath $scriptFullName).Status -eq "NotSigned") {
        Write-Warning "This script appears to be an unsigned test build. Skipping version check."
    } else {
        try {
            $versionData = [Text.Encoding]::UTF8.GetString((Invoke-WebRequestWithProxyDetection -Uri $VersionsUrl -UseBasicParsing).Content) | ConvertFrom-Csv
            $latestVersion = ($versionData | Where-Object { $_.File -eq $scriptName }).Version
            $result.LatestVersion = $latestVersion
            if ($null -ne $latestVersion) {
                $result.UpdateFound = ($latestVersion -ne $BuildVersion)
            } else {
                Write-Warning ("Unable to check for a script update as no script with the same name was found." +
                    "`r`nThis can happen if the script has been renamed. Please check manually if there is a newer version of the script.")
            }

            Write-Verbose "Current version: $($result.CurrentVersion) Latest version: $($result.LatestVersion) Update found: $($result.UpdateFound)"
        } catch {
            Write-Verbose "Unable to check for updates: $($_.Exception)"
            $result.Error = $_
        }
    }

    return $result
}


function Confirm-Signature {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $File
    )

    $IsValid = $false
    $MicrosoftSigningRoot2010 = 'CN=Microsoft Root Certificate Authority 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US'
    $MicrosoftSigningRoot2011 = 'CN=Microsoft Root Certificate Authority 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US'

    try {
        $sig = Get-AuthenticodeSignature -FilePath $File

        if ($sig.Status -ne 'Valid') {
            Write-Warning "Signature is not trusted by machine as Valid, status: $($sig.Status)."
            throw
        }

        $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
        $chain.ChainPolicy.VerificationFlags = "IgnoreNotTimeValid"

        if (-not $chain.Build($sig.SignerCertificate)) {
            Write-Warning "Signer certificate doesn't chain correctly."
            throw
        }

        if ($chain.ChainElements.Count -le 1) {
            Write-Warning "Certificate Chain shorter than expected."
            throw
        }

        $rootCert = $chain.ChainElements[$chain.ChainElements.Count - 1]

        if ($rootCert.Certificate.Subject -ne $rootCert.Certificate.Issuer) {
            Write-Warning "Top-level certificate in chain is not a root certificate."
            throw
        }

        if ($rootCert.Certificate.Subject -ne $MicrosoftSigningRoot2010 -and $rootCert.Certificate.Subject -ne $MicrosoftSigningRoot2011) {
            Write-Warning "Unexpected root cert. Expected $MicrosoftSigningRoot2010 or $MicrosoftSigningRoot2011, but found $($rootCert.Certificate.Subject)."
            throw
        }

        Write-Host "File signed by $($sig.SignerCertificate.Subject)"

        $IsValid = $true
    } catch {
        $IsValid = $false
    }

    $IsValid
}

<#
.SYNOPSIS
    Overwrites the current running script file with the latest version from the repository.
.NOTES
    This function always overwrites the current file with the latest file, which might be
    the same. Get-ScriptUpdateAvailable should be called first to determine if an update is
    needed.

    In many situations, updates are expected to fail, because the server running the script
    does not have internet access. This function writes out failures as warnings, because we
    expect that Get-ScriptUpdateAvailable was already called and it successfully reached out
    to the internet.
#>
function Invoke-ScriptUpdate {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([boolean])]
    param ()

    $scriptName = $script:MyInvocation.MyCommand.Name
    $scriptPath = [IO.Path]::GetDirectoryName($script:MyInvocation.MyCommand.Path)
    $scriptFullName = (Join-Path $scriptPath $scriptName)

    $oldName = [IO.Path]::GetFileNameWithoutExtension($scriptName) + ".old"
    $oldFullName = (Join-Path $scriptPath $oldName)
    $tempFullName = (Join-Path ((Get-Item $env:TEMP).FullName) $scriptName)

    if ($PSCmdlet.ShouldProcess("$scriptName", "Update script to latest version")) {
        try {
            Invoke-WebRequestWithProxyDetection -Uri "https://github.com/microsoft/CSS-Exchange/releases/latest/download/$scriptName" -OutFile $tempFullName
        } catch {
            Write-Warning "AutoUpdate: Failed to download update: $($_.Exception.Message)"
            return $false
        }

        try {
            if (Confirm-Signature -File $tempFullName) {
                Write-Host "AutoUpdate: Signature validated."
                if (Test-Path $oldFullName) {
                    Remove-Item $oldFullName -Force -Confirm:$false -ErrorAction Stop
                }
                Move-Item $scriptFullName $oldFullName
                Move-Item $tempFullName $scriptFullName
                Remove-Item $oldFullName -Force -Confirm:$false -ErrorAction Stop
                Write-Host "AutoUpdate: Succeeded."
                return $true
            } else {
                Write-Warning "AutoUpdate: Signature could not be verified: $tempFullName."
                Write-Warning "AutoUpdate: Update was not applied."
            }
        } catch {
            Write-Warning "AutoUpdate: Failed to apply update: $($_.Exception.Message)"
        }
    }

    return $false
}

<#
    Determines if the script has an update available. Use the optional
    -AutoUpdate switch to make it update itself. Pass -Confirm:$false
    to update without prompting the user. Pass -Verbose for additional
    diagnostic output.

    Returns $true if an update was downloaded, $false otherwise. The
    result will always be $false if the -AutoUpdate switch is not used.
#>
function Test-ScriptVersion {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Need to pass through ShouldProcess settings to Invoke-ScriptUpdate')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $AutoUpdate,
        [Parameter(Mandatory = $false)]
        [string]
        $VersionsUrl = "https://github.com/microsoft/CSS-Exchange/releases/latest/download/ScriptVersions.csv"
    )

    $updateInfo = Get-ScriptUpdateAvailable $VersionsUrl
    if ($updateInfo.UpdateFound) {
        if ($AutoUpdate) {
            return Invoke-ScriptUpdate
        } else {
            Write-Warning "$($updateInfo.ScriptName) $BuildVersion is outdated. Please download the latest, version $($updateInfo.LatestVersion)."
        }
    }

    return $false
}

function Write-Host {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Proper handling of write host with colors')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 1, ValueFromPipeline)]
        [object]$Object,
        [switch]$NoNewLine,
        [string]$ForegroundColor
    )
    process {
        $consoleHost = $host.Name -eq "ConsoleHost"

        if ($null -ne $Script:WriteHostManipulateObjectAction) {
            $Object = & $Script:WriteHostManipulateObjectAction $Object
        }

        $params = @{
            Object    = $Object
            NoNewLine = $NoNewLine
        }

        if ([string]::IsNullOrEmpty($ForegroundColor)) {
            if ($null -ne $host.UI.RawUI.ForegroundColor -and
                $consoleHost) {
                $params.Add("ForegroundColor", $host.UI.RawUI.ForegroundColor)
            }
        } elseif ($ForegroundColor -eq "Yellow" -and
            $consoleHost -and
            $null -ne $host.PrivateData.WarningForegroundColor) {
            $params.Add("ForegroundColor", $host.PrivateData.WarningForegroundColor)
        } elseif ($ForegroundColor -eq "Red" -and
            $consoleHost -and
            $null -ne $host.PrivateData.ErrorForegroundColor) {
            $params.Add("ForegroundColor", $host.PrivateData.ErrorForegroundColor)
        } else {
            $params.Add("ForegroundColor", $ForegroundColor)
        }

        Microsoft.PowerShell.Utility\Write-Host @params

        if ($null -ne $Script:WriteHostDebugAction -and
            $null -ne $Object) {
            &$Script:WriteHostDebugAction $Object
        }
    }
}

function SetProperForegroundColor {
    $Script:OriginalConsoleForegroundColor = $host.UI.RawUI.ForegroundColor

    if ($Host.UI.RawUI.ForegroundColor -eq $Host.PrivateData.WarningForegroundColor) {
        Write-Verbose "Foreground Color matches warning's color"

        if ($Host.UI.RawUI.ForegroundColor -ne "Gray") {
            $Host.UI.RawUI.ForegroundColor = "Gray"
        }
    }

    if ($Host.UI.RawUI.ForegroundColor -eq $Host.PrivateData.ErrorForegroundColor) {
        Write-Verbose "Foreground Color matches error's color"

        if ($Host.UI.RawUI.ForegroundColor -ne "Gray") {
            $Host.UI.RawUI.ForegroundColor = "Gray"
        }
    }
}

function RevertProperForegroundColor {
    $Host.UI.RawUI.ForegroundColor = $Script:OriginalConsoleForegroundColor
}

function SetWriteHostAction ($DebugAction) {
    $Script:WriteHostDebugAction = $DebugAction
}

function SetWriteHostManipulateObjectAction ($ManipulateObject) {
    $Script:WriteHostManipulateObjectAction = $ManipulateObject
}
$wsh = New-Object -ComObject WScript.Shell

function ConnectToEXOTenants {
    #Connect to SourceTenant (EXO)
    Write-Verbose -Message "Informational: Connecting to SOURCE EXO tenant"
    $wsh.Popup("You're about to connect to source tenant (EXO), please provide the SOURCE tenant admin credentials", 0, "SOURCE tenant") | Out-Null
    Connect-ExchangeOnline -Prefix Source -ShowBanner:$false

    #Connect to TargetTenant (EXO)
    Write-Verbose -Message "Informational: Connecting to TARGET EXO tenant"
    $wsh.Popup("You're about to connect to target tenant (EXO), please provide the TARGET tenant admin credentials", 0, "TARGET tenant") | Out-Null
    Connect-ExchangeOnline -Prefix Target -ShowBanner:$false
}
function ConnectToSourceEXOTenant {
    #Connect to SourceTenant (EXO)
    Write-Verbose -Message "Informational: Connecting to SOURCE EXO tenant"
    $wsh.Popup("You're about to connect to source tenant (EXO), please provide the SOURCE tenant admin credentials", 0, "SOURCE tenant") | Out-Null
    Connect-ExchangeOnline -Prefix Source -ShowBanner:$false
}
function ConnectToTargetEXOTenant {
    #Connect to SourceTenant (EXO)
    Write-Verbose -Message "Informational: Connecting to TARGET EXO tenant"
    $wsh.Popup("You're about to connect to target tenant (EXO), please provide the TARGET tenant admin credentials", 0, "TARGET tenant") | Out-Null
    Connect-ExchangeOnline -Prefix Target -ShowBanner:$false
}
function CheckObjects {

    Write-Host "Informational: Loading SOURCE object $($SourceIdentity)"
    $SourceObject = Get-SourceMailbox $SourceIdentity -ErrorAction SilentlyContinue
    Write-Host "Informational: Loading TARGET object $($TargetIdentity)"
    $TargetObject = Get-TargetMailUser $TargetIdentity -ErrorAction SilentlyContinue

    #Validate if SourceObject is present
    if ($SourceObject) {
        #Since SourceObject is valid, validate if TargetObject is present
        if ($TargetObject) {
            #Check if source mailbox has aux archives and if so throw error, otherwise continue with the rest of validations
            Write-Verbose -Message "Checking if SOURCE mailbox has any aux-archives present, and if so, no more than 12"
            $auxArchiveCount = 0
            $MailboxLocations = $SourceObject.MailboxLocations | Where-Object { ($_ -like '*auxArchive*') }
            $auxArchiveCount = $MailboxLocations.count
            Write-Verbose -Message $auxArchiveCount" aux archives are present on SOURCE mailbox"
            if ($auxArchiveCount -gt 12) {
                Write-Host ">> Error: The SOURCE mailbox has more than 12 auxArchive present and we can't migrate that much." -ForegroundColor Red
                exit
            } else {
                Write-Verbose -Message "No aux archives are present on SOURCE mailbox"

                #Check for the T2T license on any of the objects (either source or target) as long as the source mailbox is a regular mailbox
                Write-Verbose -Message "Informational: Source mailbox is regular, checking if either SOURCE mailbox or TARGET MailUser has the T2T license assigned"
                if ($SourceObject.RecipientTypeDetails -eq 'UserMailbox') {
                    if ($SourceObject.PersistedCapabilities -notcontains 'ExchangeT2TMbxMove') {
                        if ($TargetObject.PersistedCapabilities -notcontains 'ExchangeT2TMbxMove') {
                            Write-Host ">> Error: Neither SOURCE mailbox or TARGET MailUser have a valid T2T migration license. This is a pre-requisite, and if the license is not assigned by the time the migration is injected, it will fail to complete" -ForegroundColor Red
                        } else {
                            Write-Verbose -Message "TARGET MailUser has a valid T2T migration license"
                        }
                    } else {
                        Write-Verbose -Message "SOURCE mailbox has a valid T2T migration license"
                    }
                } else {
                    Write-Verbose -Message "Mailbox is not regular, skipping T2T migration license validation check"
                }

                #Verify if SOURCE mailbox is under any type of hold as we won't support this and will throw an error if this is the case
                Write-Verbose -Message "Informational: Checking if the SOURCE mailbox is under a litigation hold"
                if ($SourceObject.litigationHoldEnabled) {
                    Write-Host ">> Error: SOURCE mailbox is under Litigation Hold and this is not a supported scenario" -ForegroundColor Red
                } else {
                    Write-Verbose -Message "Mailbox is not under LitigationHold"
                }
                Write-Verbose -Message "Informational: Checking if the SOURCE mailbox is under any delay hold"
                if ($SourceObject.DelayHoldApplied) {
                    Write-Host ">> Error: SOURCE mailbox is under a Delay Hold Applied and this is not a supported scenario" -ForegroundColor Red
                } else {
                    Write-Verbose -Message "Mailbox is not under Delay Hold Applied"
                }
                if ($SourceObject.DelayReleaseHoldApplied) {
                    Write-Host ">> Error: SOURCE mailbox is under a Delay Release Hold and this is not a supported scenario" -ForegroundColor Red
                } else {
                    Write-Verbose -Message "Mailbox is not under Delay Release Hold"
                }
                if ($SourceObject.ComplianceTagHoldApplied) {
                    Write-Host ">> Error: SOURCE mailbox has labeled items with a Retention Label and this is not a supported scenario" -ForegroundColor Red
                } else {
                    Write-Verbose -Message "Mailbox is not under ComplianceTagHold"
                }
                if ($SourceObject.InPlaceHolds) {
                    $SourceObject.InPlaceHolds | ForEach-Object {
                        #This will identify Purview retention policies that may apply to mailbox (mbx without an '-') or Skype content stored on the mailbox (skp), also compliance portal eDiscovery case (UniH), and legacy InPlaceHolds starting with cld.
                        if (($_ -like "mbx*") -or ($_ -like "cld*") -or ($_ -like "UniH*") -or ($_ -like "skp*")) {
                            Write-Host ">> Error: SOURCE mailbox is under an In-PlaceHold Hold and this is not a supported scenario" -ForegroundColor Red
                        } else {
                            Write-Verbose -Message "Mailbox is not under any In-PlaceHold"
                        }
                        #This will identify legacy InPlaceHolds (eDiscovery holds) since they are always 32 chars long, while the rest aren't.
                        if (($_).length -eq 32) {
                            Write-Host ">> Error: SOURCE mailbox is under a legacy In-PlaceHold and this is not a supported scenario" -ForegroundColor Red
                        } else {
                            Write-Verbose -Message "Mailbox is not under any legacy In-Place Hold"
                        }
                    }
                }
                #Check if the mailbox is under any organizational hold
                $MailboxDiagnosticLogs = Export-SourceMailboxDiagnosticLogs $SourceObject -ComponentName HoldTracking
                if ($MailboxDiagnosticLogs.MailboxLog -like '*"hid":"mbx*","ht":4*') {
                    Write-Host ">> Error: SOURCE mailbox is under an Organizational Hold and this is not a supported scenario" -ForegroundColor Red
                } else {
                    Write-Verbose -Message "Mailbox is not under any Organizational Hold"
                }

                #Verify if SOURCE mailbox has an Archive, and if it does, check if there's any item within recoverable items SubstrateHolds folder.
                if ($SourceObject.ArchiveGUID -notmatch "00000000-0000-0000-0000-000000000000") {
                    Write-Verbose -Message "Informational: SOURCE mailbox has an Archive enabled, checking if there's any SubstrateHold folder present"
                    $ArchiveSubstrateHolds = (Get-SourceMailboxFolderStatistics $SourceObject.ArchiveGuid -FolderScope RecoverableItems -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'SubstrateHolds' })
                    if ($ArchiveSubstrateHolds) {
                        Write-Verbose -Message "Informational: SubstrateHolds folder found in SOURCE Archive mailbox, checking if there's any content inside it"
                        if (($ArchiveSubstrateHolds).ItemsInFolder -gt 0) {
                            Write-Host ">> Error: SOURCE Archive mailbox has items within the SubstrateHolds folder and this will cause the migration to fail. Please work on removing those items with MFCMapi manually before creating the move for this mailbox" -ForegroundColor Red
                        } else {
                            Write-Verbose -Message "Informational: No items found within the Archive mailbox SubstrateHolds folder"
                        }
                    } else {
                        Write-Verbose -Message "Informational: No SubstrateHolds folder found in SOURCE Archive mailbox"
                    }
                } else {
                    Write-Verbose -Message "Informational: SOURCE mailbox has no Archive enabled. Skipping Archive mailbox SubstrateHolds folder check"
                }

                #Verify if SOURCE mailbox is part of the Mail-Enabled Security Group defined on the SOURCE organization relationship
                Write-Verbose -Message "Informational: Checking if the SOURCE mailbox is a member of the SOURCE organization relationship Mail-Enabled Security Group defined on the MailboxMovePublishedScopes"
                $SourceTenantOrgRelationship = Get-SourceOrganizationRelationship | Where-Object { ($_.MailboxMoveCapability -eq "RemoteOutbound") -and ($null -ne $_.OauthApplicationId) }
                if ((Get-SourceDistributionGroupMember $SourceTenantOrgRelationship.MailboxMovePublishedScopes[0] -ResultSize unlimited).Name -contains $SourceObject.Name) {
                    Write-Host ">> SOURCE mailbox is within the MailboxMovePublishedScopes" -ForegroundColor Green
                } else {
                    Write-Host ">> Error: SOURCE mailbox is NOT within the MailboxMovePublishedScopes. The migration will fail if you don't correct this" -ForegroundColor Red
                }

                #Check the recoverableItems quota on TARGET MailUser and compare it with the SOURCE mailbox occupied quota
                Write-Verbose -Message "Checking if the current dumpster size on SOURCE mailbox is bigger than the TARGET MailUser recoverable items quota"
                if (((Get-SourceMailboxStatistics $SourceIdentity).TotalDeletedItemSize -replace '^.+\((.+\))', '$1' -replace '\D' -as [uint64]) -gt ([uint64]($TargetObject.RecoverableItemsQuota -replace '^.+\((.+\))', '$1' -replace '\D'))) {
                    Write-Host ">> Error: Dumpster size on SOURCE mailbox is bigger than TARGET MailUser RecoverableItemsQuota. This might cause the migration to fail" -ForegroundColor Red
                }

                #Verify ExchangeGuid on target object matches with source object and provide the option to set it in case it doesn't
                if (($null -eq $SourceObject.ExchangeGuid) -or ($null -eq $TargetObject.ExchangeGuid)) {
                    exit
                }
                Write-Verbose -Message "Informational: Checking ExchangeGUID"
                if ($SourceObject.ExchangeGuid -eq $TargetObject.ExchangeGuid) {
                    Write-Host ">> ExchangeGuid match ok" -ForegroundColor Green
                } else {
                    Write-Host ">> Error: ExchangeGuid mismatch. Expected value: $($SourceObject.ExchangeGuid) ,Current value: $($TargetObject.ExchangeGuid)" -ForegroundColor Red
                    $ExchangeGuidSetOption = Read-Host "Would you like to set it? (Y/N)"
                    Write-Host " Your input: $($ExchangeGuidSetOption)"
                    if ($ExchangeGuidSetOption.ToLower() -eq "y") {
                        Write-Verbose -Message "Informational: Setting correct ExchangeGUID on TARGET object"
                        Set-TargetMailUser $TargetIdentity -ExchangeGuid $SourceObject.ExchangeGuid
                        #Reload TARGET object into variable as it has been changed
                        $TargetObject = Get-TargetMailUser $TargetIdentity
                    }
                }

                #Verify if Archive is present on source and if it is, verify ArchiveGuid on target object matches with source object and provide the option to set it in case it doesn't
                Write-Verbose -Message "Informational: Checking if there's an Archive enabled on SOURCE object"
                if ($null -eq $SourceObject.ArchiveGUID) {
                    if ($null -ne $TargetObject.ArchiveGUID) {
                        Write-Host ">> Error: The TARGET MailUser $($TargetObject.Name) has an archive present while source doesn't"
                    }
                    exit
                }
                if ($SourceObject.ArchiveGuid -ne "00000000-0000-0000-0000-000000000000") {
                    Write-Verbose -Message "Informational: Archive is enabled on SOURCE object"
                    Write-Verbose -Message "Informational: Checking ArchiveGUID"
                    if ($SourceObject.ArchiveGuid -eq $TargetObject.ArchiveGuid) {
                        Write-Host ">> ArchiveGuid match ok" -ForegroundColor Green
                    } else {
                        Write-Host ">> Error: ArchiveGuid mismatch. Expected Value: $($SourceObject.ArchiveGuid) , Current value: $($TargetObject.ArchiveGuid)" -ForegroundColor Red
                        $ArchiveGuidSetOption = Read-Host "Would you like to set it? (Y/N)"
                        Write-Host " Your input: $($ArchiveGuidSetOption)"
                        if ($ArchiveGuidSetOption.ToLower() -eq "y") {
                            Write-Verbose -Message "Informational: Setting correct ArchiveGUID on TARGET object"
                            Set-TargetMailUser $TargetIdentity -ArchiveGuid $SourceObject.ArchiveGuid
                            #Reload TARGET object into variable as it has been changed
                            $TargetObject = Get-TargetMailUser $TargetIdentity
                        }
                    }
                }

                else {
                    Write-Verbose -Message "Informational: Source object has no Archive enabled"
                }

                #Verify LegacyExchangeDN is present on target object as an X500 proxy address and provide the option to add it in case it isn't
                Write-Verbose -Message "Informational: Checking if LegacyExchangeDN from SOURCE object is part of EmailAddresses on TARGET object"
                if ($null -eq $TargetObject.EmailAddresses) {
                    exit
                }
                if ($TargetObject.EmailAddresses -contains "X500:" + $SourceObject.LegacyExchangeDN) {
                    Write-Host ">> LegacyExchangeDN found as an X500 ProxyAddress on Target Object." -ForegroundColor Green
                } else {
                    Write-Host ">> Error: LegacyExchangeDN not found as an X500 ProxyAddress on Target Object. LegacyExchangeDN expected on target object: $($SourceObject.LegacyExchangeDN)" -ForegroundColor Red
                    if (!$TargetObject.IsDirSynced) {
                        $LegDNAddOption = Read-Host "Would you like to add it? (Y/N)"
                        Write-Host " Your input: $($LegDNAddOption)"
                        if ($LegDNAddOption.ToLower() -eq "y") {
                            Write-Verbose -Message "Informational: Adding LegacyExchangeDN as a proxyAddress on TARGET object"
                            Set-TargetMailUser $TargetIdentity -EmailAddresses @{Add = "X500:" + $SourceObject.LegacyExchangeDN }
                            #Reload TARGET object into variable as it has been changed
                            $TargetObject = Get-TargetMailUser $TargetIdentity
                        }
                    } else {
                        Write-Host ">> Error: The object is DirSynced and this is not a change that can be done directly on EXO. Please do the change on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                    }
                }

                #Check if the primarySMTPAddress of the target MailUser is part of the accepted domains on the target tenant and if any of the email addresses of the target MailUser doesn't belong to the target accepted domains
                Write-Verbose -Message "Informational: Loading TARGET accepted domains"
                $TargetTenantAcceptedDomains = Get-TargetAcceptedDomain

                #PrimarySMTP
                Write-Verbose -Message "Informational: Checking if the PrimarySTMPAddress of TARGET belongs to a TARGET accepted domain"
                if ($TargetTenantAcceptedDomains.DomainName -contains $TargetObject.PrimarySmtpAddress.Split('@')[1]) {
                    Write-Host ">> Target MailUser PrimarySMTPAddress is part of target accepted domains" -ForegroundColor Green
                } else {
                    Write-Host ">> Error: The Primary SMTP address $($TargetObject.PrimarySmtpAddress) of the MailUser does not belong to an accepted domain on the target tenant" -ForegroundColor Red -NoNewline
                    if (!$TargetObject.IsDirSynced) {
                        Write-Host ">> would you like to set it to $($TargetObject.UserPrincipalName) (Y/N): " -ForegroundColor Red -NoNewline
                        $PrimarySMTPAddressSetOption = Read-Host
                        Write-Host " Your input: $($PrimarySMTPAddressSetOption)"
                        if ($PrimarySMTPAddressSetOption.ToLower() -eq "y") {
                            Write-Verbose -Message "Informational: Setting the UserPrincipalName of TARGET object as the PrimarySMTPAddress"
                            Set-TargetMailUser $TargetIdentity -PrimarySmtpAddress $TargetObject.UserPrincipalName
                            #Reload TARGET object into variable as it has been changed
                            $TargetObject = Get-TargetMailUser $TargetIdentity
                        }
                    } else {
                        Write-Host ">> Error: The Primary SMTP address $($TargetObject.PrimarySmtpAddress) of the MailUser does not belong to an accepted domain on the target tenant. The object is DirSynced and this is not a change that can be done directly on EXO. Please do the change on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                    }
                }

                #EMailAddresses
                Write-Verbose -Message "Informational: Checking for EmailAddresses on TARGET object that are not on the TARGET accepted domains list"
                foreach ($Address in $TargetObject.EmailAddresses) {
                    if ($Address.StartsWith("SMTP:") -or $Address.StartsWith("smtp:")) {
                        if ($TargetTenantAcceptedDomains.DomainName -contains $Address.Split("@")[1]) {
                            Write-Host ">> EmailAddress $($Address) is part of the target accepted domains" -ForegroundColor Green
                        } else {
                            if (!$TargetObject.IsDirSynced) {
                                Write-Host ">> Error: $($Address) is not part of your organization, would you like to remove it? (Y/N): " -ForegroundColor Red -NoNewline
                                $RemoveAddressOption = Read-Host
                                Write-Host " Your input: $($RemoveAddressOption)"
                                if ($RemoveAddressOption.ToLower() -eq "y") {
                                    Write-Host "Informational: Removing the EmailAddress $($Address) from the TARGET object"
                                    Set-TargetMailUser $TargetIdentity -EmailAddresses @{Remove = $Address }
                                    #Reload TARGET object into variable as it has been changed
                                    $TargetObject = Get-TargetMailUser $TargetIdentity
                                }
                            } else {
                                Write-Host ">> Error: $($Address) is not part of your organization. The object is DirSynced and this is not a change that can be done directly on EXO. Please do remove the address from on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                            }
                        }
                    }
                }

                #Sync X500 addresses from source mailbox to target mailUser
                Write-Verbose -Message "Informational: Checking for missing X500 addresses on TARGET that are present on SOURCE mailbox"
                if ($SourceObject.EmailAddresses -like '*500:*') {
                    Write-Verbose -Message "SOURCE mailbox contains X500 addresses, checking if they're present on the TARGET MailUser"
                    foreach ($Address in ($SourceObject.EmailAddresses | Where-Object { $_ -like '*500:*' })) {
                        if ($TargetObject.EmailAddresses -contains $Address) {
                            Write-Verbose -Message "Informational: The X500 address $($Address) from SOURCE object is present on TARGET object"
                        } else {
                            if (!$TargetObject.IsDirSynced) {
                                Write-Host ">> Warning: $($Address) is not present on the TARGET MailUser. All of the X500 addresses of the source mailbox object, as a best practice, should be present on the target MailUser object. Would you like to add it? (Y/N): " -ForegroundColor Yellow -NoNewline
                                $AddX500 = Read-Host
                                Write-Host " Your input: $($AddX500)"
                                if ($AddX500.ToLower() -eq "y") {
                                    Write-Host "Informational: Adding the X500 Address $($Address) on the TARGET object"
                                    Set-TargetMailUser $TargetIdentity -EmailAddresses @{Add = $Address }
                                    #Reload TARGET object into variable as it has been changed
                                    $TargetObject = Get-TargetMailUser $TargetIdentity
                                }
                            } else {
                                Write-Host ">> Warning: $($Address) is not present on the TARGET MailUser and the object is DirSynced. All of the X500 addresses of the source mailbox object, as a best practice, should be present on the target MailUser object. This is not a change that can be done directly on EXO, please add the X500 address from on-premises and perform an AADConnect delta sync" -ForegroundColor Yellow
                            }
                        }
                    }
                } else {
                    Write-Verbose -Message "Informational: SOURCE mailbox doesn't contain any X500 address"
                }

                #Check ExternalEmailAddress on TargetMailUser with primarySMTPAddress from SourceMailbox:
                Write-Verbose -Message "Informational: Checking if the ExternalEmailAddress on TARGET object points to the PrimarySMTPAddress of the SOURCE object"
                if ($TargetObject.ExternalEmailAddress.Split(":")[1] -eq $SourceObject.PrimarySmtpAddress) {
                    Write-Host ">> ExternalEmailAddress of Target MailUser is pointing to PrimarySMTPAddress of Source Mailbox" -ForegroundColor Green
                } else {
                    if (!$TargetObject.IsDirSynced) {
                        Write-Host ">> Error: TargetMailUser ExternalEmailAddress value $($TargetObject.ExternalEmailAddress) does not match the PrimarySMTPAddress of the SourceMailbox $($SourceObject.PrimarySmtpAddress) , would you like to set it? (Y/N): " -ForegroundColor Red -NoNewline
                        $RemoveAddressOption = Read-Host
                        Write-Host " Your input: $($RemoveAddressOption)"
                        if ($RemoveAddressOption.ToLower() -eq "y") {
                            Write-Host "Informational: Setting the ExternalEmailAddress of SOURCE object to $($SourceObject.PrimarySmtpAddress)"
                            Set-TargetMailUser $TargetIdentity -ExternalEmailAddress $SourceObject.PrimarySmtpAddress
                            #Reload TARGET object into variable as it has been changed
                            $TargetObject = Get-TargetMailUser $TargetIdentity
                        }
                    } else {
                        Write-Host ">> Error: TargetMailUser ExternalEmailAddress value $($TargetObject.ExternalEmailAddress) does not match the PrimarySMTPAddress of the SourceMailbox $($SourceObject.PrimarySmtpAddress). The object is DirSynced and this is not a change that can be done directly on EXO. Please do the change on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                    }
                }
            }
        }

        else {
            Write-Host ">> Error: $($TargetIdentity) wasn't found on TARGET tenant" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: $($SourceIdentity) wasn't found on SOURCE tenant" -ForegroundColor Red
    }
}
function CheckObjectsSourceOffline {

    Write-Host "Informational: Loading SOURCE object $($SourceIdentity)"
    $SourceObject = Import-Clixml $OutputPath\SourceMailbox_$SourceIdentity.xml
    Write-Host "Informational: Loading TARGET object $($TargetIdentity)"
    $TargetObject = Get-TargetMailUser $TargetIdentity -ErrorAction SilentlyContinue

    #Validate if SourceObject is present
    if ($SourceObject) {
        #Since SourceObject is valid, validate if TargetObject is present
        if ($TargetObject) {
            #Check if source mailbox has aux archives and if so throw error, otherwise continue with the rest of validations
            Write-Verbose -Message "Checking if SOURCE mailbox has any aux-archives present, and if so, no more than 12"
            $auxArchiveCount = 0
            $MailboxLocations = $SourceObject.MailboxLocations | Where-Object { ($_ -like '*auxArchive*') }
            $auxArchiveCount = $MailboxLocations.count
            Write-Verbose -Message $auxArchiveCount" aux archives are present on SOURCE mailbox"
            if ($auxArchiveCount -gt 12) {
                Write-Host ">> Error: The SOURCE mailbox has more than 12 auxArchive present and we can't migrate that much." -ForegroundColor Red
                exit
            } else {
                Write-Verbose -Message "No aux archives are present on SOURCE mailbox"

                #Check for the T2T license on any of the objects (either source or target) as long as the source mailbox is a regular mailbox
                Write-Verbose -Message "Informational: Source mailbox is regular, checking if either SOURCE mailbox or TARGET MailUser has the T2T license assigned"
                if ($SourceObject.RecipientTypeDetails -eq 'UserMailbox') {
                    if ($SourceObject.PersistedCapabilities -notcontains 'ExchangeT2TMbxMove') {
                        if ($TargetObject.PersistedCapabilities -notcontains 'ExchangeT2TMbxMove') {
                            Write-Host ">> Error: Neither SOURCE mailbox or TARGET MailUser have a valid T2T migration license. This is a pre-requisite, and if the license is not assigned by the time the migration is injected, it will fail to complete" -ForegroundColor Red
                        } else {
                            Write-Verbose -Message "TARGET MailUser has a valid T2T migration license"
                        }
                    } else {
                        Write-Verbose -Message "SOURCE mailbox has a valid T2T migration license"
                    }
                } else {
                    Write-Verbose -Message "Mailbox is not regular, skipping T2T migration license validation check"
                }

                #Verify if SOURCE mailbox is under any type of hold as we won't support this and will throw an error if this is the case
                Write-Verbose -Message "Informational: Checking if the SOURCE mailbox is under a litigation hold"
                if ($SourceObject.litigationHoldEnabled) {
                    Write-Host ">> Error: SOURCE mailbox is under Litigation Hold. This move is not supported as it would lead into data loss" -ForegroundColor Red
                }
                Write-Verbose -Message "Informational: Checking if the SOURCE mailbox is under any delay hold"
                if ($SourceObject.DelayHoldApplied) {
                    Write-Host ">> Error: SOURCE mailbox is under a Delay Hold. This move is not supported as it would lead into data loss" -ForegroundColor Red
                }
                if ($SourceObject.DelayReleaseHoldApplied) {
                    Write-Host ">> Error: SOURCE mailbox is under a Delay Release Hold. This move is not supported as it would lead into data loss" -ForegroundColor Red
                }
                if ($SourceObject.ComplianceTagHoldApplied) {
                    Write-Host ">> Error: SOURCE mailbox has labeled items with a Retention Label. This move is not supported as it would lead into data loss" -ForegroundColor Red
                }
                if ($SourceObject.InPlaceHolds) {
                    $SourceObject.InPlaceHolds | ForEach-Object {
                        #This will identify Purview retention policies that may apply to mailbox (mbx without an '-') or Skype content stored on the mailbox (skp), also compliance portal eDiscovery case (UniH), and legacy InPlaceHolds starting with cld.
                        if (($_ -like "mbx*") -or ($_ -like "cld*") -or ($_ -like "UniH*") -or ($_ -like "skp*")) {
                            Write-Host ">> Error: SOURCE mailbox is under an In-PlaceHold Hold. This move is not supported as it would lead into data loss" -ForegroundColor Red
                        }
                        #This will identify legacy InPlaceHolds (eDiscovery holds) since they are always 32 chars long, while the rest aren't.
                        if (($_).length -eq 32) {
                            Write-Host ">> Error: SOURCE mailbox is under an In-PlaceHold Hold. This move is not supported as it would lead into data loss" -ForegroundColor Red
                        }
                    }
                }
                #Check if the mailbox is under any organizational hold
                $MailboxDiagnosticLogs = Import-Clixml $OutputPath\MailboxDiagnosticLogs_$SourceIdentity.xml
                if ($MailboxDiagnosticLogs.MailboxLog -like '*"hid":"mbx*","ht":4*') {
                    Write-Host ">> Error: SOURCE mailbox is under an Organizational Hold. This move is not supported as it would lead into data loss" -ForegroundColor Red
                }

                #Verify if SOURCE mailbox has an Archive, and if it does, check if there's any item within recoverable items SubstrateHolds folder.
                if ($SourceObject.ArchiveGUID -notmatch "00000000-0000-0000-0000-000000000000") {
                    Write-Verbose -Message "Informational: SOURCE mailbox has an Archive enabled, checking if there's any SubstrateHold folder present"
                    if (Test-Path $OutputPath\ArchiveMailboxStatistics_$SourceIdentity.xml) {
                        $ArchiveMailboxFolderStatistics = Import-Clixml $OutputPath\ArchiveMailboxStatistics_$SourceIdentity.xml
                        if ($ArchiveMailboxFolderStatistics.Name -eq 'SubstrateHolds') {
                            if ($ArchiveMailboxFolderStatistics.ItemsInFolder -gt 0) {
                                Write-Host ">> Error: SOURCE Archive mailbox has items within the SubstrateHolds folder and this will cause the migration to fail. Please work on removing those items with MFCMapi manually before creating the move for this mailbox" -ForegroundColor Red
                            } else {
                                Write-Verbose -Message "Informational: No items found within the Archive mailbox SubstrateHolds folder"
                            }
                        } else {
                            Write-Verbose -Message "Informational: No SubstrateHolds folder found in SOURCE Archive mailbox"
                        }
                    } else {
                        Write-Verbose -Message "Informational: SOURCE archive mailbox had no recoverable items"
                    }
                } else {
                    Write-Verbose -Message "Informational: SOURCE mailbox has no Archive enabled. Skipping Archive mailbox SubstrateHolds folder check"
                }

                #Verify if SOURCE mailbox is part of the Mail-Enabled Security Group defined on the SOURCE organization relationship
                Write-Verbose -Message "Informational: Checking if the SOURCE mailbox is a member of the SOURCE organization relationship Mail-Enabled Security Group defined on the MailboxMovePublishedScopes"
                $SourceTenantOrgRelationship = (Import-Clixml $OutputPath\SourceOrgRelationship.xml)
                $SourceTenantOrgRelationship = $SourceTenantOrgRelationship | Where-Object { ($_.MailboxMoveCapability -eq "RemoteOutbound") -and ($null -ne $_.OauthApplicationId) }
                $SourceTenantMailboxMovePublishedScopesSGMembers = Import-Clixml $OutputPath\MailboxMovePublishedScopesSGMembers.xml
                if ($SourceTenantMailboxMovePublishedScopesSGMembers.Name -contains $SourceObject.Name) {
                    Write-Host ">> SOURCE mailbox is within the MailboxMovePublishedScopes" -ForegroundColor Green
                } else {
                    Write-Host ">> Error: SOURCE mailbox is NOT within the MailboxMovePublishedScopes. The migration will fail if you don't correct this" -ForegroundColor Red
                }

                #Check the recoverableItems quota on TARGET MailUser and compare it with the SOURCE mailbox occupied quota
                Write-Verbose -Message "Checking if the current dumpster size on SOURCE mailbox is bigger than the TARGET MailUser recoverable items quota"
                $SourceMailboxStatistics = Import-Clixml $OutputPath\MailboxStatistics_$SourceIdentity.xml
                if (($SourceMailboxStatistics.TotalDeletedItemSize -replace '^.+\((.+\))', '$1' -replace '\D' -as [uint64]) -gt ([uint64]($TargetObject.RecoverableItemsQuota -replace '^.+\((.+\))', '$1' -replace '\D'))) {
                    Write-Host ">> Error: Dumpster size on SOURCE mailbox is bigger than TARGET MailUser RecoverableItemsQuota. This might cause the migration to fail" -ForegroundColor Red
                }

                #Verify ExchangeGuid on target object matches with source object and provide the option to set it in case it doesn't
                if (($null -eq $SourceObject.ExchangeGuid) -or ($null -eq $TargetObject.ExchangeGuid)) {
                    exit
                }
                Write-Verbose -Message "Informational: Checking ExchangeGUID"
                if ($SourceObject.ExchangeGuid -eq $TargetObject.ExchangeGuid) {
                    Write-Host ">> ExchangeGuid match ok" -ForegroundColor Green
                } else {
                    Write-Host ">> Error: ExchangeGuid mismatch. Expected value: $($SourceObject.ExchangeGuid) ,Current value: $($TargetObject.ExchangeGuid)" -ForegroundColor Red
                    $ExchangeGuidSetOption = Read-Host "Would you like to set it? (Y/N)"
                    Write-Host " Your input: $($ExchangeGuidSetOption)"
                    if ($ExchangeGuidSetOption.ToLower() -eq "y") {
                        Write-Verbose -Message "Informational: Setting correct ExchangeGUID on TARGET object"
                        Set-TargetMailUser $TargetIdentity -ExchangeGuid $SourceObject.ExchangeGuid
                        #Reload TARGET object into variable as it has been changed
                        $TargetObject = Get-TargetMailUser $TargetIdentity
                    }
                }

                #Verify if Archive is present on source and if it is, verify ArchiveGuid on target object matches with source object and provide the option to set it in case it doesn't
                Write-Verbose -Message "Informational: Checking if there's an Archive enabled on SOURCE object"
                if ($null -eq $SourceObject.ArchiveGUID) {
                    if ($null -ne $TargetObject.ArchiveGUID) {
                        Write-Host ">> Error: The TARGET MailUser $($TargetObject.Name) has an archive present while source doesn't"
                    }
                    exit
                }
                if ($SourceObject.ArchiveGuid -ne "00000000-0000-0000-0000-000000000000") {
                    Write-Verbose -Message "Informational: Archive is enabled on SOURCE object"
                    Write-Verbose -Message "Informational: Checking ArchiveGUID"
                    if ($SourceObject.ArchiveGuid -eq $TargetObject.ArchiveGuid) {
                        Write-Host ">> ArchiveGuid match ok" -ForegroundColor Green
                    } else {
                        Write-Host ">> Error: ArchiveGuid mismatch. Expected Value: $($SourceObject.ArchiveGuid) , Current value: $($TargetObject.ArchiveGuid)" -ForegroundColor Red
                        $ArchiveGuidSetOption = Read-Host "Would you like to set it? (Y/N)"
                        Write-Host " Your input: $($ArchiveGuidSetOption)"
                        if ($ArchiveGuidSetOption.ToLower() -eq "y") {
                            Write-Verbose -Message "Informational: Setting correct ArchiveGUID on TARGET object"
                            Set-TargetMailUser $TargetIdentity -ArchiveGuid $SourceObject.ArchiveGuid
                            #Reload TARGET object into variable as it has been changed
                            $TargetObject = Get-TargetMailUser $TargetIdentity
                        }
                    }
                }

                else {
                    Write-Verbose -Message "Informational: Source object has no Archive enabled"
                }

                #Verify LegacyExchangeDN is present on target object as an X500 proxy address and provide the option to add it in case it isn't
                Write-Verbose -Message "Informational: Checking if LegacyExchangeDN from SOURCE object is part of EmailAddresses on TARGET object"
                if ($null -eq $TargetObject.EmailAddresses) {
                    exit
                }
                if ($TargetObject.EmailAddresses -contains "X500:" + $SourceObject.LegacyExchangeDN) {
                    Write-Host ">> LegacyExchangeDN found as an X500 ProxyAddress on Target Object." -ForegroundColor Green
                } else {
                    Write-Host ">> Error: LegacyExchangeDN not found as an X500 ProxyAddress on Target Object. LegacyExchangeDN expected on target object: $($SourceObject.LegacyExchangeDN)" -ForegroundColor Red
                    if (!$TargetObject.IsDirSynced) {
                        $LegDNAddOption = Read-Host "Would you like to add it? (Y/N)"
                        Write-Host " Your input: $($LegDNAddOption)"
                        if ($LegDNAddOption.ToLower() -eq "y") {
                            Write-Verbose -Message "Informational: Adding LegacyExchangeDN as a proxyAddress on TARGET object"
                            Set-TargetMailUser $TargetIdentity -EmailAddresses @{Add = "X500:" + $SourceObject.LegacyExchangeDN }
                            #Reload TARGET object into variable as it has been changed
                            $TargetObject = Get-TargetMailUser $TargetIdentity
                        }
                    } else {
                        Write-Host ">> Error: The object is DirSynced and this is not a change that can be done directly on EXO. Please do the change on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                    }
                }

                #Check if the primarySMTPAddress of the target MailUser is part of the accepted domains on the target tenant and if any of the email addresses of the target MailUser doesn't belong to the target accepted domains
                Write-Verbose -Message "Informational: Loading TARGET accepted domains"
                $TargetTenantAcceptedDomains = Get-TargetAcceptedDomain

                #PrimarySMTP
                Write-Verbose -Message "Informational: Checking if the PrimarySTMPAddress of TARGET belongs to a TARGET accepted domain"
                if ($TargetTenantAcceptedDomains.DomainName -contains $TargetObject.PrimarySmtpAddress.Split('@')[1]) {
                    Write-Host ">> Target MailUser PrimarySMTPAddress is part of target accepted domains" -ForegroundColor Green
                } else {
                    Write-Host ">> Error: The Primary SMTP address $($TargetObject.PrimarySmtpAddress) of the MailUser does not belong to an accepted domain on the target tenant" -ForegroundColor Red -NoNewline
                    if (!$TargetObject.IsDirSynced) {
                        Write-Host ">> would you like to set it to $($TargetObject.UserPrincipalName) (Y/N): " -ForegroundColor Red -NoNewline
                        $PrimarySMTPAddressSetOption = Read-Host
                        Write-Host " Your input: $($PrimarySMTPAddressSetOption)"
                        if ($PrimarySMTPAddressSetOption.ToLower() -eq "y") {
                            Write-Verbose -Message "Informational: Setting the UserPrincipalName of TARGET object as the PrimarySMTPAddress"
                            Set-TargetMailUser $TargetIdentity -PrimarySmtpAddress $TargetObject.UserPrincipalName
                            #Reload TARGET object into variable as it has been changed
                            $TargetObject = Get-TargetMailUser $TargetIdentity
                        }
                    } else {
                        Write-Host ">> Error: The Primary SMTP address $($TargetObject.PrimarySmtpAddress) of the MailUser does not belong to an accepted domain on the target tenant. The object is DirSynced and this is not a change that can be done directly on EXO. Please do the change on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                    }
                }

                #EMailAddresses
                Write-Verbose -Message "Informational: Checking for EmailAddresses on TARGET object that are not on the TARGET accepted domains list"
                foreach ($Address in $TargetObject.EmailAddresses) {
                    if ($Address.StartsWith("SMTP:") -or $Address.StartsWith("smtp:")) {
                        if ($TargetTenantAcceptedDomains.DomainName -contains $Address.Split("@")[1]) {
                            Write-Host ">> EmailAddress $($Address) is part of the target accepted domains" -ForegroundColor Green
                        } else {
                            if (!$TargetObject.IsDirSynced) {
                                Write-Host ">> Error: $($Address) is not part of your organization, would you like to remove it? (Y/N): " -ForegroundColor Red -NoNewline
                                $RemoveAddressOption = Read-Host
                                Write-Host " Your input: $($RemoveAddressOption)"
                                if ($RemoveAddressOption.ToLower() -eq "y") {
                                    Write-Host "Informational: Removing the EmailAddress $($Address) from the TARGET object"
                                    Set-TargetMailUser $TargetIdentity -EmailAddresses @{Remove = $Address }
                                    #Reload TARGET object into variable as it has been changed
                                    $TargetObject = Get-TargetMailUser $TargetIdentity
                                }
                            } else {
                                Write-Host ">> Error: $($Address) is not part of your organization. The object is DirSynced and this is not a change that can be done directly on EXO. Please do remove the address from on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                            }
                        }
                    }
                }

                #Sync X500 addresses from source mailbox to target mailUser
                Write-Verbose -Message "Informational: Checking for missing X500 addresses on TARGET that are present on SOURCE mailbox"
                if ($SourceObject.EmailAddresses -like '*500:*') {
                    Write-Verbose -Message "SOURCE mailbox contains X500 addresses, checking if they're present on the TARGET MailUser"
                    foreach ($Address in ($SourceObject.EmailAddresses | Where-Object { $_ -like '*500:*' })) {
                        if ($TargetObject.EmailAddresses -contains $Address) {
                            Write-Verbose -Message "Informational: The X500 address $($Address) from SOURCE object is present on TARGET object"
                        } else {
                            if (!$TargetObject.IsDirSynced) {
                                Write-Host ">> Error: $($Address) is not present on the TARGET MailUser. All of the X500 addresses of the source mailbox object, as a best practice, should be present on the target MailUser object. Would you like to add it? (Y/N): " -ForegroundColor Red -NoNewline
                                $AddX500 = Read-Host
                                Write-Host " Your input: $($AddX500)"
                                if ($AddX500.ToLower() -eq "y") {
                                    Write-Host "Informational: Adding the X500 Address $($Address) on the TARGET object"
                                    Set-TargetMailUser $TargetIdentity -EmailAddresses @{Add = $Address }
                                    #Reload TARGET object into variable as it has been changed
                                    $TargetObject = Get-TargetMailUser $TargetIdentity
                                }
                            } else {
                                Write-Host ">> Error: $($Address) is not present on the TARGET MailUser and the object is DirSynced. All of the X500 addresses of the source mailbox object, as a best practice, should be present on the target MailUser object. This is not a change that can be done directly on EXO, please add the X500 address from on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                            }
                        }
                    }
                } else {
                    Write-Verbose -Message "Informational: SOURCE mailbox doesn't contain any X500 address"
                }

                #Check ExternalEmailAddress on TargetMailUser with primarySMTPAddress from SourceMailbox:
                Write-Verbose -Message "Informational: Checking if the ExternalEmailAddress on TARGET object points to the PrimarySMTPAddress of the SOURCE object"
                if ($TargetObject.ExternalEmailAddress.Split(":")[1] -eq $SourceObject.PrimarySmtpAddress) {
                    Write-Host ">> ExternalEmailAddress of Target MailUser is pointing to PrimarySMTPAddress of Source Mailbox" -ForegroundColor Green
                } else {
                    if (!$TargetObject.IsDirSynced) {
                        Write-Host ">> Error: TargetMailUser ExternalEmailAddress value $($TargetObject.ExternalEmailAddress) does not match the PrimarySMTPAddress of the SourceMailbox $($SourceObject.PrimarySmtpAddress) , would you like to set it? (Y/N): " -ForegroundColor Red -NoNewline
                        $RemoveAddressOption = Read-Host
                        Write-Host " Your input: $($RemoveAddressOption)"
                        if ($RemoveAddressOption.ToLower() -eq "y") {
                            Write-Host "Informational: Setting the ExternalEmailAddress of SOURCE object to $($SourceObject.PrimarySmtpAddress)"
                            Set-TargetMailUser $TargetIdentity -ExternalEmailAddress $SourceObject.PrimarySmtpAddress
                            #Reload TARGET object into variable as it has been changed
                            $TargetObject = Get-TargetMailUser $TargetIdentity
                        }
                    } else {
                        Write-Host ">> Error: TargetMailUser ExternalEmailAddress value $($TargetObject.ExternalEmailAddress) does not match the PrimarySMTPAddress of the SourceMailbox $($SourceObject.PrimarySmtpAddress). The object is DirSynced and this is not a change that can be done directly on EXO. Please do the change on-premises and perform an AADConnect delta sync" -ForegroundColor Red
                    }
                }
            }
        }

        else {
            Write-Host ">> Error: $($TargetIdentity) wasn't found on TARGET tenant" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: $($SourceIdentity) wasn't found on SOURCE tenant" -ForegroundColor Red
    }
}
function ConnectToSourceTenantAAD {
    #Connect to TargetTenant (AzureAD)
    Write-Verbose -Message "Informational: Connecting to AAD on SOURCE tenant"
    $wsh.Popup("You're about to connect to source tenant (AAD), please provide the SOURCE tenant admin credentials", 0, "SOURCE tenant") | Out-Null
    Connect-MgGraph -Scopes 'Application.Read.All' | Out-Null
}
function ConnectToTargetTenantAAD {
    #Connect to TargetTenant (AzureAD)
    Write-Verbose -Message "Informational: Connecting to AAD on TARGET tenant"
    $wsh.Popup("You're about to connect to target tenant (AAD), please provide the TARGET tenant admin credentials", 0, "TARGET tenant") | Out-Null
    Connect-MgGraph -Scopes 'Application.Read.All' | Out-Null
}
function CheckOrgs {
    #Check if there's an AAD app on the TARGET tenant as expected and load it onto a variable
    if ($TargetAADApp) {
        Write-Host "AAD application for EXO has been found on TARGET tenant" -ForegroundColor Green
        Write-Verbose -Message "Informational: Loading migration endpoints on TARGET tenant that meets the criteria"
        if (Get-TargetMigrationEndpoint | Where-Object { ($_.RemoteServer -eq "outlook.office.com") -and ($_.EndpointType -eq "ExchangeRemoteMove") -and ($_.ApplicationId -eq $TargetAADApp.AppId) }) {
            Write-Host "Migration endpoint found and correctly set" -ForegroundColor Green
        } else {
            Write-Host ">> Error: Expected Migration endpoint not found" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: No AAD application for EXO has been found" -ForegroundColor Red
    }

    # Check if there's an AAD app on the SOURCE tenant that matches the TargetTenantId
    if (($SourceAADApp | Where-Object { $_.Appid -eq $TargetAADApp.Appid }).AppOwnerOrganizationId -eq $TargetTenantId) {
        Write-Host "AAD application for EXO has been found on SOURCE tenant matching TARGET tenant" -ForegroundColor Green
        Write-Verbose -Message "Informational: AAD Application matching SOURCE AppId has been found on TARGET tenant"
    } else {
        Write-Host ">> Error: No AAD Application matching SOURCE AppId has been found on TARGET tenant" -ForegroundColor Red
    }

    #Check orgRelationship flags on source and target orgs
    Write-Verbose -Message "Informational: Loading Organization Relationship on SOURCE tenant that meets the criteria"
    $SourceTenantOrgRelationship = Get-SourceOrganizationRelationship | Where-Object { $_.OauthApplicationId -eq $TargetAADApp.AppId }
    Write-Verbose -Message "Informational: Loading Organization Relationship on TARGET tenant that meets the criteria"
    $TargetTenantOrgRelationship = Get-TargetOrganizationRelationship | Where-Object { $_.DomainNames -contains $SourceTenantId }

    Write-Verbose -Message "Informational: Checking TARGET tenant organization relationship"
    if ($TargetTenantOrgRelationship) {
        Write-Host "Organization relationship on TARGET tenant DomainNames is correctly pointing to SourceTenantId" -ForegroundColor Green
        if ($TargetTenantOrgRelationship.MailboxMoveEnabled) {
            Write-Host "Organization relationship on TARGET tenant is enabled for moves" -ForegroundColor Green
        } else {
            Write-Host ">> Error: Organization relationship on TARGET tenant mailbox is not enabled for moves" -ForegroundColor Red
        }
        if ($TargetTenantOrgRelationship.MailboxMoveCapability -eq "Inbound") {
            Write-Host "Organization relationship on TARGET tenant MailboxMove is correctly set" -ForegroundColor Green
        } else {
            Write-Host ">> Error: Organization relationship on TARGET tenant MailboxMove is not correctly set. The expected value is 'Inbound' and the current value is $($TargetTenantOrgRelationship.MailboxMoveCapability)" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: No Organization relationship on TARGET tenant pointing to SourceTenantId has been found" -ForegroundColor Red
    }

    Write-Verbose -Message "Informational: Checking SOURCE tenant organization relationship"
    if ($SourceTenantOrgRelationship.MailboxMoveEnabled) {
        Write-Host "Organization relationship on SOURCE tenant is enabled for moves" -ForegroundColor Green
        if ($SourceTenantOrgRelationship.MailboxMoveCapability -eq "RemoteOutbound") {
            Write-Host "Organization relationship on SOURCE tenant MailboxMove is correctly set" -ForegroundColor Green
            if ($SourceTenantOrgRelationship.DomainNames -contains $TargetTenantId) {
                Write-Host "Organization relationship on SOURCE tenant DomainNames is correctly pointing to TargetTenantId" -ForegroundColor Green
            } else {
                Write-Host ">> Error: Organization relationship on SOURCE tenant DomainNames is not pointing to TargetTenantId" -ForegroundColor Red
            }
            if ($null -eq $SourceTenantOrgRelationship.MailboxMovePublishedScopes) {
                Write-Host ">> Error: Organization relationship on SOURCE tenant does not have a Mail-Enabled security group defined under the MailboxMovePublishedScopes property" -ForegroundColor Red
            }
        }

        else {
            Write-Host ">> Error: Organization relationship on SOURCE tenant MailboxMove is not correctly set. The expected value is 'RemoteOutbound' and the current value is $($TargetTenantOrgRelationship.MailboxMoveCapability)" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: Organization relationship on TARGET tenant mailbox is not enabled for moves" -ForegroundColor Red
    }
}
function CheckOrgsSourceOffline {

    #Check if there's an AAD EXO app as expected and load it onto a variable
    if ($TargetAADApp) {
        Write-Host "AAD application for EXO has been found" -ForegroundColor Green
        Write-Verbose -Message "Informational: Loading migration endpoints on TARGET tenant that meets the criteria"
        if (Get-TargetMigrationEndpoint | Where-Object { ($_.RemoteServer -eq "outlook.office.com") -and ($_.EndpointType -eq "ExchangeRemoteMove") -and ($_.ApplicationId -eq $TargetAADApp.AppId) }) {
            Write-Host "Migration endpoint found and correctly set" -ForegroundColor Green
        } else {
            Write-Host ">> Error: Expected Migration endpoint not found" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: No AAD application for EXO has been found" -ForegroundColor Red
    }

    # Check if there's an AAD app on the SOURCE tenant that matches the TargetTenantId
    if (($SourceAADApp | Where-Object { $_.Appid -eq $TargetAADApp.Appid }).AppOwnerOrganizationId -eq $TargetTenantId) {
        Write-Host "AAD application for EXO has been found on SOURCE tenant matching TARGET tenant" -ForegroundColor Green
        Write-Verbose -Message "Informational: AAD Application matching SOURCE AppId has been found on TARGET tenant"
    } else {
        Write-Host ">> Error: No AAD Application matching SOURCE AppId has been found on TARGET tenant" -ForegroundColor Red
    }

    #Check orgRelationship flags on source and target orgs
    Write-Verbose -Message "Informational: Loading Organization Relationship on SOURCE tenant that meets the criteria"
    $SourceTenantOrgRelationship = (Import-Clixml $OutputPath\SourceOrgRelationship.xml)
    Write-Verbose -Message "Informational: Loading Organization Relationship on TARGET tenant that meets the criteria"
    $TargetTenantOrgRelationship = Get-TargetOrganizationRelationship | Where-Object { $_.DomainNames -contains $SourceTenantId }

    Write-Verbose -Message "Informational: Checking TARGET tenant organization relationship"
    if ($TargetTenantOrgRelationship) {
        Write-Host "Organization relationship on TARGET tenant DomainNames is correctly pointing to SourceTenantId" -ForegroundColor Green
        if ($TargetTenantOrgRelationship.MailboxMoveEnabled) {
            Write-Host "Organization relationship on TARGET tenant is enabled for moves" -ForegroundColor Green
        } else {
            Write-Host ">> Error: Organization relationship on TARGET tenant mailbox is not enabled for moves" -ForegroundColor Red
        }
        if ($TargetTenantOrgRelationship.MailboxMoveCapability -eq "Inbound") {
            Write-Host "Organization relationship on TARGET tenant MailboxMove is correctly set" -ForegroundColor Green
        } else {
            Write-Host ">> Error: Organization relationship on TARGET tenant MailboxMove is not correctly set. The expected value is 'Inbound' and the current value is $($TargetTenantOrgRelationship.MailboxMoveCapability)" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: No Organization relationship on TARGET tenant pointing to SourceTenantId has been found" -ForegroundColor Red
    }

    Write-Verbose -Message "Informational: Checking SOURCE tenant organization relationship"
    if ($SourceTenantOrgRelationship.MailboxMoveEnabled) {
        Write-Host "Organization relationship on SOURCE tenant is enabled for moves" -ForegroundColor Green
        if ($SourceTenantOrgRelationship.MailboxMoveCapability -eq "RemoteOutbound") {
            Write-Host "Organization relationship on SOURCE tenant MailboxMove is correctly set" -ForegroundColor Green
            if ($SourceTenantOrgRelationship.DomainNames -contains $TargetTenantId) {
                Write-Host "Organization relationship on SOURCE tenant DomainNames is correctly pointing to TargetTenantId" -ForegroundColor Green
            } else {
                Write-Host ">> Error: Organization relationship on SOURCE tenant DomainNames is not pointing to TargetTenantId" -ForegroundColor Red
            }
            if ($null -eq $SourceTenantOrgRelationship.MailboxMovePublishedScopes) {
                Write-Host ">> Error: Organization relationship on SOURCE tenant does not have a Mail-Enabled security group defined under the MailboxMovePublishedScopes property" -ForegroundColor Red
            }
        }

        else {
            Write-Host ">> Error: Organization relationship on SOURCE tenant MailboxMove is not correctly set. The expected value is 'RemoteOutbound' and the current value is $($TargetTenantOrgRelationship.MailboxMoveCapability)" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: Organization relationship on TARGET tenant mailbox is not enabled for moves" -ForegroundColor Red
    }
}
function KillSessions {
    #Check if there's any existing session opened for EXO and remove it so it doesn't remains open
    Get-PSSession | Where-Object { $_.ComputerName -eq 'outlook.office365.com' } | Remove-PSSession
}
function CollectDataForSDP {
    $currentDate = (Get-Date).ToString('ddMMyyHHMM')
    if (Test-Path $PathForCollectedData -PathType Container) {
        $OutputPath = New-Item -ItemType Directory -Path $PathForCollectedData -Name $currentDate | Out-Null
        $OutputPath = $PathForCollectedData + '\' + $currentDate
    } else {
        Write-Host ">> Error: The specified folder doesn't exist, please specify an existent one" -ForegroundColor Red
        exit
    }

    #Collect the Exchange Online data and export it to an XML file
    Write-Host "Informational: Saving SOURCE tenant id to text file"  -ForegroundColor Yellow
    "SourceTenantId: " + $SourceTenantId | Out-File $OutputPath\TenantIds.txt
    Write-Host "Informational: Saving TARGET tenant id to text file"  -ForegroundColor Yellow
    "TargetTenantId: " + $TargetTenantId | Out-File $OutputPath\TenantIds.txt -Append
    Write-Host "Informational: Exporting the SOURCE tenant Azure AD service principals" -ForegroundColor Yellow
    $SourceAADApp | Export-Clixml $OutputPath\SourceAADApps.xml
    Write-Host "Informational: Exporting the SOURCE tenant organization relationship"  -ForegroundColor Yellow
    Get-SourceOrganizationRelationship | Export-Clixml $OutputPath\SourceOrgRelationship.xml
    Write-Host "Informational: Exporting the TARGET tenant migration endpoint"  -ForegroundColor Yellow
    Get-TargetMigrationEndpoint | Export-Clixml $OutputPath\TargetMigrationEndpoint.xml
    Write-Host "Informational: Exporting the TARGET tenant organization relationship"  -ForegroundColor Yellow
    Get-TargetOrganizationRelationship | Export-Clixml $OutputPath\TargetOrgRelationship.xml
    Write-Host "Informational: Exporting the TARGET tenant accepted domains"  -ForegroundColor Yellow
    Get-TargetAcceptedDomain | Export-Clixml $OutputPath\TargetAcceptedDomains.xml
    Write-Host "Informational: Exporting the TARGET tenant Azure AD applications" -ForegroundColor Yellow
    Get-MgApplication | Where-Object { ($_.Web.RedirectUris -eq "https://office.com") -and ($_.RequiredResourceAccess.ResourceAppId -like "*00000002-0000-0ff1-ce00-000000000000*") } | Export-Clixml $OutputPath\TargetAADApps.xml

    #Compress folder contents into a zip file
    Write-Host "Informational: Data has been exported. Compressing it into a ZIP file"  -ForegroundColor Yellow
    if ((Get-ChildItem $OutputPath).count -gt 0) {
        try {
            Compress-Archive -Path $OutputPath\*.XML -DestinationPath $PathForCollectedData\CTMMCollectedData$currentDate.zip -Force
            Compress-Archive -Path $OutputPath\TenantIds.txt -DestinationPath $PathForCollectedData\CTMMCollectedData$currentDate.zip -Update
            Write-Host "Informational: ZIP file has been generated with a total of $((Get-ChildItem $OutputPath).count) files, and can be found at $($PathForCollectedData)\CTMMCollectedData$currentDate.zip so it can be sent to Microsoft Support if needed, however you can still access the raw data at $($OutputPath)"  -ForegroundColor Yellow
        } catch {
            Write-Host ">> Error: There was an issue trying to compress the exported data" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: No data has been detected at $($OutputPath), so there's nothing to compress" -ForegroundColor Red
    }
}
function CollectSourceData {
    #Collect the source Exchange Online data of the provided mailboxes via CSV file and export it to an XML file including mailbox diagnostic logs and mailbox statistics
    Write-Host "Informational: Exporting the SOURCE mailbox properties for $($SourceIdentity)" -ForegroundColor Yellow
    $SourceObject = Get-SourceMailbox $SourceIdentity
    $SourceObject | Export-Clixml $OutputPath\SourceMailbox_$SourceIdentity.xml

    Write-Host "Informational: Exporting the SOURCE mailbox diagnostic logs for $($SourceIdentity)" -ForegroundColor Yellow
    Export-SourceMailboxDiagnosticLogs $SourceIdentity -ComponentName HoldTracking | Export-Clixml $OutputPath\MailboxDiagnosticLogs_$SourceIdentity.xml

    Write-Host "Informational: Exporting the SOURCE mailbox statistics for $($SourceIdentity)" -ForegroundColor Yellow
    Get-SourceMailboxStatistics $SourceIdentity | Export-Clixml $OutputPath\MailboxStatistics_$SourceIdentity.xml
    if ($SourceObject.ArchiveGuid -notmatch "00000000-0000-0000-0000-000000000000") {
        $SourceArchiveRI = Get-SourceMailboxFolderStatistics $SourceObject.ArchiveGuid -FolderScope RecoverableItems -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'SubstrateHolds' }
        if ($SourceArchiveRI) {
            $SourceArchiveRI | Export-Clixml $OutputPath\ArchiveMailboxStatistics_$SourceIdentity.xml
        } else {
            Write-Host "Informational: The Archive mailbox is present but there are no recoverable items present. Bypassing the export" -ForegroundColor Yellow
        }
    }
}
function ExpandCollectedData {
    #Expand zip file gathered from the CollectSourceData process provided on the 'PathForCollectedData' parameter
    Write-Host "Informational: Trying to expand exported data from the source tenant specified on the 'PathForCollectedData' parameter"
    if ($PathForCollectedData -like '*\CTMMCollectedSourceData.zip') {
        try {
            $OutputPath = $PathForCollectedData.TrimEnd('CTMMCollectedSourceData.zip') + 'CTMMCollectedSourceData'
            Expand-Archive -Path $PathForCollectedData -DestinationPath $OutputPath -Force
            Write-Host "Informational: ZIP file has been expanded with a total of $((Get-ChildItem $OutputPath).count) files"
        } catch {
            Write-Host ">> Error: There was an issue trying to expand the compressed data" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: No CTMMCollectedData.zip file has been specified, you must provide the 'PathForCollectedData' parameter with a valid path including the 'CTMMCollectedSourceData.zip' filename. i.e.: C:\temp\CTMMCollectedSourceData.zip" -ForegroundColor Red
    }
}
function LoggingOn {
    Write-Host ""
    Write-Host ""
    if (Test-Path $LogPath -PathType Leaf) {
        Write-Host ">> Error: The log file already exists, please specify a different name and run again" -ForegroundColor Red
        exit
    } else {
        Start-Transcript -Path $LogPath -NoClobber
    }
}
function LoggingOff {
    Stop-Transcript
}

if ($ScriptUpdateOnly) {
    switch (Test-ScriptVersion -AutoUpdate -VersionsUrl "https://aka.ms/CrossTenantMailboxMigrationValidationScript-VersionsURL" -Confirm:$false) {
    ($true) { Write-Host ("Script was successfully updated") -ForegroundColor Green }
    ($false) { Write-Host ("No update of the script performed") -ForegroundColor Yellow }
        default { Write-Host (">> Error: Unable to perform ScriptUpdateOnly operation") -ForegroundColor Red }
    }
    return
}

if ((-not($SkipVersionCheck)) -and
    (Test-ScriptVersion -AutoUpdate -VersionsUrl "https://aka.ms/CrossTenantMailboxMigrationValidationScript-VersionsURL" -Confirm:$false)) {
    Write-Host ("Script was updated. Please re-run the script") -ForegroundColor Yellow
    return
}

if ($CheckObjects -and !$NoConn -and !$SourceIsOffline) {
    LoggingOn
    if ($CSV) {
        $Objects = Import-Csv $CSV
        if (($Objects.SourceUser) -and ($Objects.TargetUser)) {
            ConnectToEXOTenants
            foreach ($object in $Objects) {
                $SourceIdentity = $object.SourceUser
                $TargetIdentity = $object.TargetUser
                Write-Host ""
                Write-Host "----------------------------------------" -ForegroundColor Cyan
                Write-Host "----------------------------------------" -ForegroundColor Cyan
                Write-Host ""
                Write-Host $SourceIdentity" is being used as SOURCE object"
                Write-Host $TargetIdentity" is being used as TARGET object"
                CheckObjects
            }
        } else {
            Write-Host ">> Error: Invalid CSV file, please make sure you specify a correct one with the 'SourceUser' and 'TargetUser' columns" -ForegroundColor Red
            LoggingOff
            exit
        }
    } else {
        $SourceIdentity = Read-Host "Please type the SOURCE object to check at"
        $TargetIdentity = Read-Host "Please type the TARGET object to compare with"
        ConnectToEXOTenants
        Write-Host ""
        Write-Host "----------------------------------------" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor Cyan
        Write-Host ""
        CheckObjects
    }
    LoggingOff
    KillSessions
}

if ($CheckOrgs -and !$SourceIsOffline) {
    LoggingOn
    ConnectToSourceTenantAAD
    $SourceTenantId = (Get-MgOrganization).id
    Write-Verbose -Message "Informational: SourceTenantId gathered from (Get-MgOrganization).id: $SourceTenantId"
    $SourceAADApp = Get-MgServicePrincipal -All
    Write-Verbose -Message "Informational: AAD apps gathered from MgServicePrincipal"
    Disconnect-MgGraph | Out-Null
    ConnectToTargetTenantAAD
    $TargetTenantId = (Get-MgOrganization).id
    Write-Verbose -Message "Informational: TargetTenantId gathered from (Get-MgOrganization).id: $TargetTenantId"
    Write-Verbose -Message "Informational: Checking if there's already an AAD Application on TARGET tenant that meets the criteria"
    $TargetAADApp = Get-MgApplication | Where-Object { ($_.Web.RedirectUris -eq "https://office.com") -and ($_.RequiredResourceAccess.ResourceAppId -like "*00000002-0000-0ff1-ce00-000000000000*") }
    Disconnect-MgGraph | Out-Null
    ConnectToEXOTenants
    CheckOrgs
    LoggingOff
    KillSessions
}

if ($SDP) {
    LoggingOn
    ConnectToEXOTenants
    ConnectToSourceTenantAAD
    $SourceTenantId = (Get-MgOrganization).id
    $SourceAADApp = Get-MgServicePrincipal -All
    Disconnect-MgGraph | Out-Null
    ConnectToTargetTenantAAD
    $TargetTenantId = (Get-MgOrganization).id
    CollectDataForSDP
    Disconnect-MgGraph | Out-Null
    LoggingOff
    KillSessions
}

if ($CollectSourceOnly -and $CSV) {
    LoggingOn
    #Create the folders based on date and time to store the files
    $currentDate = (Get-Date).ToString('ddMMyyHHMM')
    if (Test-Path $PathForCollectedData -PathType Container) {
        $OutputPath = New-Item -ItemType Directory -Path $PathForCollectedData -Name $currentDate | Out-Null
        $OutputPath = $PathForCollectedData + '\' + $currentDate
    } else {
        Write-Host ">> Error: The specified folder at the PathForCollectedData parameter doesn't exist, please specify an existent one and make sure you only specify a path with no filename" -ForegroundColor Red
        exit
    }
    ConnectToSourceTenantAAD
    $SourceTenantId = (Get-MgOrganization).id
    Write-Verbose -Message "SourceTenantId gathered from (Get-MgOrganization).id: $SourceTenantId"
    Write-Verbose -Message "Gathering AAD Service Principals"
    Get-MgServicePrincipal -All | Where-Object { $_.ReplyUrls -eq 'https://office.com' } | Export-Clixml $OutputPath\SourceAADServicePrincipals.xml
    $Objects = Import-Csv $CSV
    if ($Objects.SourceUser) {
        Write-Verbose -Message "Informational: CSV file contains the SourceUser column, now we need to connect to the source EXO tenant"
        ConnectToSourceEXOTenant

        #Collect the TenantId and OrganizationConfig only once and leave the foreach only to mailboxes we need to collect data from
        Write-Host "Informational: Saving SOURCE tenant id to text file"  -ForegroundColor Yellow
        $SourceTenantId | Out-File $OutputPath\SourceTenantId.txt

        Write-Host "Informational: Exporting the SOURCE tenant organization relationships"  -ForegroundColor Yellow
        $SourceTenantOrganizationRelationship = Get-SourceOrganizationRelationship
        $SourceTenantOrganizationRelationship | Export-Clixml $OutputPath\SourceOrgRelationship.xml

        Write-Host "Informational: Checking if there's a published scope defined on the organization relationships to extract the members"  -ForegroundColor Yellow
        $SourceTenantOrganizationRelationship | ForEach-Object {
            if (($_.MailboxMoveEnabled) -and ($_.MailboxMoveCapability -eq "RemoteOutbound") -and ($_.MailboxMovePublishedScopes)) {
                Write-Host "Informational: $($_.Identity) organization relationship meets the conditions for a cross tenant mailbox migration scenario, exporting members of the security group defined on the MailboxMovePublishedScopes" -ForegroundColor Yellow
                Get-SourceDistributionGroupMember $_.MailboxMovePublishedScopes[0] -ResultSize Unlimited | Export-Clixml $OutputPath\MailboxMovePublishedScopesSGMembers.xml
            } else {
                Write-Host "Informational: $($_.Identity) organization relationship doesn't match for a cross tenant mailbox migration scenario" -ForegroundColor Yellow
            }
        }

        foreach ($object in $Objects) {
            $SourceIdentity = $object.SourceUser
            Write-Host ""
            Write-Host "----------------------------------------" -ForegroundColor Cyan
            Write-Host "----------------------------------------" -ForegroundColor Cyan
            Write-Host ""
            Write-Host $SourceIdentity" is being used as SOURCE object"
            CollectSourceData
        }

        #Compress folder contents into a zip file
        Write-Host "Informational: Source data has been exported. Compressing it into a ZIP file"  -ForegroundColor Yellow
        if ((Get-ChildItem $OutputPath).count -gt 0) {
            try {
                Copy-Item $CSV -Destination $OutputPath\UsersToProcess.csv
                Compress-Archive -Path $OutputPath\*.* -DestinationPath $PathForCollectedData\CTMMCollectedSourceData.zip -Force
                Write-Host "Informational: ZIP file has been generated with a total of $((Get-ChildItem $OutputPath).count) files, and can be found at $($PathForCollectedData)\CTMMCollectedSourceData.zip so it can be sent to the target tenant administrator, however you can still access the raw data at $($OutputPath)"  -ForegroundColor Yellow
            } catch {
                Write-Host ">> Error: There was an issue trying to compress the exported data" -ForegroundColor Red
            }
        } else {
            Write-Host ">> Error: No data has been detected at $($OutputPath), so there's nothing to compress" -ForegroundColor Red
        }
    } else {
        Write-Host ">> Error: Invalid CSV file, please make sure you specify a correct one with the 'SourceUser' column" -ForegroundColor Red
        exit
    }
    Disconnect-MgGraph | Out-Null
    LoggingOff
    KillSessions
}

if ($SourceIsOffline -and $PathForCollectedData -and $CheckObjects) {
    LoggingOn
    ConnectToTargetEXOTenant
    ExpandCollectedData
    $OutputPath = $PathForCollectedData.TrimEnd('CTMMCollectedSourceData.zip') + 'CTMMCollectedSourceData'
    Write-Verbose -Message "OutputPath: $OutputPath"
    $CSV2 = Import-Csv $OutputPath\UsersToProcess.csv
    if ($CSV2.SourceUser) {
        Write-Verbose -Message "Informational: CSV file contains the SourceUser column"
    } else {
        Write-Host ">> Error: Invalid CSV file, please make sure the file contains the 'SourceUser' column" -ForegroundColor Red
        exit
    }

    foreach ($c in $CSV2) {
        $SourceIdentity = $c.SourceUser
        $TargetIdentity = $c.SourceUser.Split('@')[0]
        CheckObjectsSourceOffline
    }
    LoggingOff
    KillSessions
}

if ($SourceIsOffline -and $PathForCollectedData -and $CheckOrgs) {
    LoggingOn
    ExpandCollectedData
    $OutputPath = $PathForCollectedData.TrimEnd('CTMMCollectedSourceData.zip') + 'CTMMCollectedSourceData'
    Write-Verbose -Message "OutputPath: $OutputPath"
    ConnectToTargetTenantAAD
    $SourceTenantId = Get-Content $OutputPath\SourceTenantId.txt
    Write-Verbose -Message "SourceTenantId gathered from SourceTenantId.txt: $SourceTenantId"
    $TargetTenantId = (Get-MgOrganization).id
    Write-Verbose -Message "TargetTenantId gathered from (Get-MgOrganization).id: $TargetTenantId"
    $SourceAADApp = (Import-Clixml $OutputPath\SourceAADServicePrincipals.xml)
    Write-Verbose -Message "Informational: Checking if there's already an AAD Application on TARGET tenant that meets the criteria"
    $TargetAADApp = Get-MgApplication | Where-Object { ($_.Web.RedirectUris -eq "https://office.com") -and ($_.RequiredResourceAccess.ResourceAppId -like "*00000002-0000-0ff1-ce00-000000000000*") }
    ConnectToTargetEXOTenant
    CheckOrgsSourceOffline
    Disconnect-MgGraph | Out-Null
    LoggingOff
    KillSessions
}
