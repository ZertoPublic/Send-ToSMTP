# Legal Disclaimer 
This script is an example script and is not supported under any Zerto support program or service. The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.

In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you.

# Send To SMTP 
Leveraging the Zerto Rest API this script will authenticate with the ZVM to pull the alerts from the relevant ZVM to the host scripting this script. Leveraging an input CSV ($excludedAlert) the user can then filter out
the alerts they do not wish to be received via SMTP. This requires the alert ID (i.e. LIC0007) be entered into the CSV and the CSV saved before running the script. Once the alerts have been filtered an email title and body
will be created and leveraging the native PowerShell Send-MailMessage command an email will be sent the addresses specified. Each time the script is run it will create a JSON file called Bookmark, on the next iteration of
the script it will read the book mark file to extract the time stamp and only pull new alerts that occurred since the last time the API was queried.

It is important that the necessary ports between the scripting host and the ZVM API (9669) are open, as well as necessary ports from the scripting host to the email server the message will be sent to. The 
script can be run regularly as a job in Task Manager or another scheduling application on an interval determined by the user.  

If you do not wish to filter out any alerts do not leverage a CSV to import the alert IDs. For those users who do wish to filter out specific alerts the AlertID.CSV provided can be leveraged as an example. You must leave the column header "AlertID" in the file, place the specific alert IDs into the column below Alert ID, no commas are necessary. For a list of alerts and alert IDs please reference the Zerto Alarms, Alerts, and Events PDF.  

# Prerequisities
Environment Requirements: 
  - PowerShell 5.0 +
  - ZVR 5.0u3+ 

Script Requirements: 
  - Log Directory
  - Book mark JSON file directory
  - Import Alert Filter CSV Directory
  - ZVM IP 
  - ZVM User / password 
  - SMTP Server IP Address
  - Email Sender address
  - Email Recipient
  - Email CC Address
 
# Running Script 
Once the necessary requirements have been completed select an appropriate host to run the script from. To run the script type the following:

.\Send-ToSMTP.ps1
