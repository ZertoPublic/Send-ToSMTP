#requires -RunAsAdministrator
#requires -Version 5.0 

<#
.SYNOPSIS
This script is designed to query the recovery Zerto alerts API and then send the requested alerts to the users specified in the email address. 

.DESCRIPTION
Leveraging the Zerto Rest API this script will authenticate with the ZVM to pull the alerts from the relevant ZVM to the host scripting this script. Leveraging an input CSV ($excludedAlert) the user can then filter out
the alerts they do not wish to be received via SMTP. This requires the alert ID (i.e. LIC0007) be entered into the CSV and the CSV saved before running the script. Once the alerts have been filtered an email title and body
will be created and leveraging the native PowerShell Send-MailMessage command an email will be sent the addresses specified.  

It is important that the necessary ports between the scripting host and the ZVM API (9669) are open, as well as necessary ports from the scripting host to the email server the message will be sent to. The 
script can be run regularly as a job in Task Manager or another scheduling application on an interval determined by the user.   

.EXAMPLE
Examples of script execution

.VERSION
This script can only run on ZVR 6.5u2 or higher. 

.LEGAL
Legal Disclaimer:
 
----------------------
This script is an example script and is not supported under any Zerto support program or service.
The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.
 
In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without
limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability
to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages. The entire risk arising out of the use or
performance of the sample scripts and documentation remains with you.
----------------------
#>

################ Variables for your script ######################
$strZVMIP = "EnterZVMIP"
$strZVMPort = "9669"
$strZVMUser = "EnterZVMUser"
$strZVMPwd = "EnterZVMPassword"
$LogDataDir = "EnterLogDirectory"
$reportOutput = "EnterReportOutpuDirectory"
$smtpSender = "EnterEmailSenderAccount"
$smtpReceive = "EnterEmailAddressToReceive"
$smtpCC = "EnterCCEmailAddressIfNeeded"
$smtpServer = "EnterSMTPServerAddress"
$strZVMURL = "https://" + $strZVMIP + ":" + $strZVMPort + "/zvm#/main/monitoring/alerts"
$strURLIDDetails = "/Help/index.html#context/ErrorsGuide/"
$bookMarkFile = "EnterLocationForBookMarkFileToBeSaved"
$excludedAlert = "EnterLocationOfCSVFile"

########################################################################################################################
# Nothing to configure below this line - Starting the main function of the script
########################################################################################################################

Write-Host -ForegroundColor Yellow "Informational line denoting start of script GOES HERE." 
Write-Host -ForegroundColor Yellow "   Legal Disclaimer:

----------------------
This script is an example script and is not supported under any Zerto support program or service.
The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.

In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without 
limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability 
to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages.  The entire risk arising out of the use or 
performance of the sample scripts and documentation remains with you.
----------------------
"
#------------------------------------------------------------------------------#
#Setting log directory and starting transcript logging
#------------------------------------------------------------------------------#
$CurrentMonth = get-date -Format MM.yy
$CurrentTime = get-date -format hh.mm.ss
$CurrentLogDataDir = $LogDataDir + $CurrentMonth
$CurrentLogDataFile = $LogDataDir + "-" + $CurrentMonth + "\SendToSMTP-" + $CurrentTime + ".txt"

#Testing path exists, if not creating it
$ExportDataDirTestPath = test-path $CurrentLogDataDir
If($ExportDataDirTestPath -eq $False)
{
New-item -ItemType Directory -Force -Path $CurrentLogDataDir
}#EndIf
start-transcript -path $CurrentLogDataFile -NoClobber

#Testing CSV output path, if not creating it
$reportTestPath = test-path $reportOutput
If($reportTestPath -eq $False){
    New-item -ItemType Directory -Force -Path $reportOutput
}#EndIf

############### ignore self signed SSL ##########################
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
}#EndIf
[ServerCertificateValidationCallback]::Ignore()
#################################################################

#--------------------------------------------------------------------------------------------------#
# Function Definitions
#--------------------------------------------------------------------------------------------------#
Function getxZertoSession ($userName, $password){
    $baseURL = "https://" + $strZVMIP + ":" + $strZVMPort
    $xZertoSessionURL = $baseURL +"/v1/session/add"
    $authInfo = ("{0}:{1}" -f $userName,$password)
    $authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
    $authInfo = [System.Convert]::ToBase64String($authInfo)
    $headers = @{Authorization=("Basic {0}" -f $authInfo)}
    $contentType = "application/json"
    $xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURL -Headers $headers -Method POST -ContentType $contentType

    return $xZertoSessionResponse.headers.get_item("x-zerto-session")
}#End getxZertoSession Function


#------------------------------------------------------------------------------#
#Extract x-zerto-session from the response, and add it to the API: 
#------------------------------------------------------------------------------#
$xZertoSession = getxZertoSession $strZVMUser $strZVMPwd
$zertoSessionHeader = @{"x-zerto-session"=$xZertoSession}
$zertoSessionHeader_json = @{"Accept"="application/json"
"x-zerto-session"=$xZertoSession}


#------------------------------------------------------------------------------#
# Importing the CSV of Excluded Alerts
#------------------------------------------------------------------------------#
$excludedAlertsCSVImport = Import-Csv $excludedAlert
$excludedAlerts = $excludedAlertsCSVImport.AlertID

#------------------------------------------------------------------------------#
# Configuring Bookmark file for timestamp 
#------------------------------------------------------------------------------#
If(Test-Path $bookMarkFile){
    
    #If bookmark exists, add 1 millisecond to timestamp for next alert query
    [DateTime]$currentBookmark = $(get-content -raw -path $bookMarkFile | convertfrom-json).value
    $startTime = $currentBookmark.AddMilliseconds(1).toString('yyyy-MM-ddTHH:mm:ss.fff')
      
}#EndIf
Else{
    
    #If bookmark does not exist, use ZVR install date as alert query start time
    $startTime = ((Get-Date).AddMinutes(-5)).ToString('yyyy-MM-ddTHH:mm:ss.fff') 

}#EndElse

#------------------------------------------------------------------------------#
# Build PeersList API URL
#------------------------------------------------------------------------------#
$peerListApiUrl = "https://" + $strZVMIP + ":"+$strZVMPort+"/v1/alerts?startDate="+$startTime

#------------------------------------------------------------------------------#
# Iterate with JSON:
#------------------------------------------------------------------------------#
$alertListJSON = Invoke-RestMethod -Uri $peerListApiUrl -Headers $zertoSessionHeader

If ($alertListJSON){
    $latestAlert = $alertListJSON[0].TurnedOn

    #Order alerts from oldest to newest
    $alertListJSON | sort-object {$_.TurnedOn}
    
    # loop through each alert returned, if its not to be excluded
    foreach ($alert in $alertListJSON){

        If($excludedAlerts -notcontains $alert.HelpIdentifier){

            # 
            if($latestAlert -lt $alert.TurnedOn){
                $latestAlert = $alert.TurnedOn

            }#EndIf


            $alertInfo = $alert.Description
            $TimeStamp = $alert.TurnedOn 
            $alertID = $alert.HelpIdentifier
            $siteInfo = $alert.Site.href
            $siteInfo = $siteInfo.Substring(0, $siteInfo.lastIndexOf(':'))
            $alertStatus = $alert.IsDismissed
            $alertLevel = $alert.Level
            $alertLink = "https://" + $strZVMIP + ":" + $strZVMPort + $strURLIDDetails + $alertID
    
            $EmailDescription = "Zerto Alert:" + " $alertID"
            #Delete previous $EmailBody content
            $EmailBody = $null

            #Building email body
$EmailBody += @"
This message is being sent due to the following Zerto alert being triggered in your environment:
$alertInfo

Severity: $alertLevel

Alert Timestamp: $TimeStamp

Additional details for the alert including possible causes and steps for resolution can be found at: `

"@
            $EmailBody += $AlertLink | foreach {$_ + "`n"}
            $EmailBody += "`nYou can also review the information further within the ZVM UI. Navigate to the monitoring tab and then search for the following alert ID:`n"
            $EmailBody += $strZVMURL
            $EmailBody += "`nAlert ID: $alertID`n"
            $EmailBody += "`nAlert Acknowledged: $alertStatus`n"
            $EmailBody += "`nSite: $siteInfo"

            Send-MailMessage -From $smtpSender -To $smtpReceive -Subject $EmailDescription -Body $EmailBody -SmtpServer $smtpServer 


        }#EndIf
        $latestAlert | ConvertTo-Json | Set-Content -path $bookMarkFile
    }#EndForEach
}#EndIf


#------------------------------------------------------------------------------#
# Ending API Session
#------------------------------------------------------------------------------#
$deleteApiSessionURL = "https://" + $strZVMIP + ":"+$strZVMPort+"/v1/session"
Invoke-WebRequest -Uri $deleteApiSessionURL -Headers $zertoSessionHeader -Method Delete -ContentType $contentType

Exit
##End of script
