###############################################################################
##
## This script checks an Office 365 email inbox folder for emails,
## looks for language for approve or reject, locates the url for a
## SharePoint task to approve or reject, and updates that task.
##
## Referenced the following: https://sysadminben.wordpress.com/2016/06/15/read-email-in-folder-in-o365/
##
###############################################################################

# The path where the files for this script reside
$DirPath = "C:\Scripts\EmailApprovals"
$CredsPath = "C:\Scripts"

# Set the path to your copy of EWS Managed API 
# Add the paths to the dlls we want to import
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.WorkflowServices.dll"
$dllpath = $DirPath + "\DLLs\Microsoft.Exchange.WebServices.dll" 
# Load the Assemply 
[void][Reflection.Assembly]::LoadFile($dllpath) 

# Constants
$APPROVED = "Approved"
$REJECTED = "Rejected"
$STARTOFREPLY = "From:"
$EMAILINBOXFOLDER = "Email Approvals"					 
$EMAILPROCESSEDFOLDER = "Email Approvals Processed"
$EMAILNOTPROCESSEDFOLDER = "Email Approvals Not Processed"
$URLPATTERN = "url"
$TASKURLPATTERN = "taskUrl"
$IDPATTERN = "id="

# Text for Approve/Reject key words
$APPROVETEXT1 = "*approve*"
$APPROVETEXT2 = "*yes*"
$APPROVETEXT3 = "*acknowledge*"
$REJECTTEXT1 = "*reject*"

# Email to CC if there are any issues processing the task
$toNotProcessed = "errors@vivityconsulting.com"

# Path to the folder that contains our log file
$LogPath = $DirPath + "\Logs\"

#  Log file time stamp:
$Time = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
$LogFile = $LogPath + "EmailApprovals-" + $Time + ".txt"

# Encrypted Credential files
$CredsFileSharePoint = $CredsPath + "\adcreds_sharepoint.txt"
$CredsFileEmail = $CredsPath + "\adcreds_email.txt"

# The user to access email
$UserEmail = "email.approvals@vivityconsulting.com"
# The user to access SharePoint
$UserSharePoint = "sys_admin@vivityconsulting.com"

# Create a new Exchange service object 
$service = new-object Microsoft.Exchange.WebServices.Data.ExchangeService 

# Get AD Credentials
$credEmail = New-Object -TypeName System.Management.Automation.PSCredential  -ArgumentList $UserEmail, (Get-Content $CredsFileEmail | ConvertTo-SecureString)
$credSharePoint = New-Object -TypeName System.Management.Automation.PSCredential  -ArgumentList $UserSharePoint, (Get-Content $CredsFileSharePoint | ConvertTo-SecureString)

# Get credentials for SharePointOnline
$spoCred = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($credSharePoint.GetNetworkCredential().Username, (ConvertTo-SecureString $credSharePoint.GetNetworkCredential().Password -AsPlainText -Force))

#These are your O365 credentials
$service.Credentials = New-Object Microsoft.Exchange.WebServices.Data.WebCredentials($credEmail)

# this TestUrlCallback is purely a security check
$TestUrlCallback = {
    param ([string] $url)
    if ($url -eq "https://autodiscover-s.outlook.com/autodiscover/autodiscover.xml") {$true} else {$false}
}
# Autodiscover using the mail address set above
$service.AutodiscoverUrl($UserEmail,$TestUrlCallback)

# create Property Set to include body and header of email
$PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)

# set email body to text
$PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text

# Set how many emails we want to read at a time
$numOfEmailsToRead = 1

# Index to keep track of where we are up to. Set to 0 initially. 
$index = 0 

$view = New-Object Microsoft.Exchange.WebServices.Data.FolderView(100)
$view.PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.Webservices.Data.BasePropertySet]::FirstClassProperties)
$view.PropertySet.Add([Microsoft.Exchange.Webservices.Data.FolderSchema]::DisplayName)
$view.Traversal = [Microsoft.Exchange.Webservices.Data.FolderTraversal]::Deep


##########################################################
# Write to the console and the log file
##########################################################
Function Write-Log($text)
{
	$null = Write-Host $text
	$text | Out-File $LogFile -Append
}

##########################################################
# Get the List Item
##########################################################
Function Get-ListItem($context, $url, $listPath, $id)
{
	Write-Log("Getting List Item for ID: " + $id)
	Write-Log("url: " + $url + "  listName: " + $listPath)
    Write-Log("context url: " + $context.url)

	# Get List
	$list = $context.Web.GetList($listPath)
	$web = $context.Web
	$context.Load($list)
	$context.Load($web)
	$context.ExecuteQuery()
	
    Write-Log("Context.Web url: " + $context.Web.url)
	Write-Log("Web: " + $web.Title)
	Write-Log("Got List: " + $list.Title)
	
	# Get Single List Item
	$spListItem = $list.getItemById($id)
	$context.Load($spListItem)
	$context.ExecuteQuery()
	
	Write-Log("Title: " + $spListItem["Title"])
	
	return $spListItem
}

##########################################################
# Update the List Item
##########################################################
Function Update-ListItem($context, $spListItem, $result, $emailItem)
{	
    $title = $spListItem["Title"] 
	
	Write-Log("In Update-ListItem: $title")
	Write-Log("Result: $result")
	Write-Log("Email from: " + $emailItem.From.Address)

	$spListItem["PercentComplete"] = 1
	if ($result -eq $APPROVED)
	{
		Write-Log("Task was Approved")		
		$spListItem["TaskOutcome"] = $APPROVED
	}
	if ($result -eq $REJECTED)
	{
		Write-Log("Task was Rejected")
		$spListItem["TaskOutcome"] = $REJECTED
	}
	
	$spListItem["Body"] = $emailItem.Body
	$spListItem["Status"] = "Completed"
	$spListItem.Update()
	
	Write-Log("Updated Item")	

	$context.Load($spListItem)
	$context.ExecuteQuery()
}

##########################################################
# Determine whether it was Approved or Rejected
##########################################################
function Get-Result($text)
{
	$result = ""
	
	if ($replyText -like $REJECTTEXT1)
	{
		$result = $REJECTED
	}
		
	if ($replyText -like $APPROVETEXT1 -or $replyText -like $APPROVETEXT2 -or $replyText -like $APPROVETEXT3)
	{
		$result = $APPROVED
	}
	
	# If neither return false
	if ($result -eq "")
	{
		$result = $false
	}
	
	Write-Log("Result in Get-Result: $result")
	
	return $result
}

##########################################################
# Parse the Url for the task url, the web url,
# the list name, and the task id
##########################################################
function Parse-Url($originalEmailTextDecoded)
{
	# Url should contain either taskUrl= or url=, figure out which and get it
	# This is for our one-click task processes
	if ($originalEmailTextDecoded.Contains($TASKURLPATTERN)) 
	{
		$url = $originalEmailTextDecoded.Substring($originalEmailTextDecoded.IndexOf($TASKURLPATTERN) + 8).ToLower()
	}
	# This is for normal SharePoint Workflow task processes
	else
	{
		$url = $originalEmailTextDecoded.Substring($originalEmailTextDecoded.IndexOf($URLPATTERN) + 4).ToLower()
	}

    Write-Log("url: " + $url)
	
	if ($url.Contains("&")) { $url = $url.Substring(0, $url.IndexOf('&')) }

    Write-Log("url after removing ampersand: " + $url)
			
	$webUrl = $url.Substring(0, $url.IndexOf("/lists/"))

    Write-Log("webUrl: " + $webUrl)

    $serverRelativeWebUrl = $webUrl.Substring($webUrl.IndexOf(".com") + 4)

    Write-Log("serverRelativeWebUrl: " + $serverRelativeWebUrl)

	$listPath = $url.Substring($url.IndexOf("/lists/") + 7)
    # get the actual list path
	$listPath = $listPath.Substring(0, $listPath.IndexOf("/"))
    # add back the lists path
    $listPath = $serverRelativeWebUrl + "/lists/" + $listPath
    
    Write-Log("listPath: " + $listPath)
	
	$itemId = $url.Substring($url.IndexOf("id=") + 3)
	if ($itemId.Contains("&")) { $itemId = $itemId.Substring(0, $itemId.IndexOf("&")) }
	
	# Items to return
	$url
	$webUrl
	$listPath
	$itemId
}

##########################################################
# Process an individual email
##########################################################
function Process-Item($emailItem)
{
	Write-Log("In Process Item")

	# This is whether the item contains approve or reject
	$result = ""
	$isValid = $true

	# Load the additional properties for the item
	$emailItem.Load($propertySet)
	
	Write-Log("Item Loaded")
	
	# Get the text of the email
	$bodyText = $emailItem.Body.Text
	
	# Get the sections of the email (the Reply by the user, and the Original email to the user (which will contain the url to the task)
	if ($bodyText.IndexOf($STARTOFREPLY) -gt 0) 
	{ 
		$replyText = $bodyText.Substring(0, $bodyText.IndexOf($STARTOFREPLY))
		$originalEmailText = $bodyText.Substring($bodyText.IndexOf($STARTOFREPLY))
	}
	# If it's not a reply than the whole body should contain the reply and the link
	else
	{
		$replyText = $bodyText
		$originalEmailText = $bodyText
	}
	
	# Put the reply text to lowercase for easier matching
	if ($replyText.Length > 0) { $replyText = $replyText.ToLower() }

	# Find out if the user wanted to Approve or Reject
	$result = Get-Result($replyText)
			
	# Decode any encoded characters (particularly the links)
	$originalEmailTextDecoded = [System.Web.HttpUtility]::UrlDecode($originalEmailText)
	
	# If our original email has a task url, let's get it
	if (-Not $originalEmailTextDecoded.Contains($TASKURLPATTERN) -and -Not $originalEmailTextDecoded.Contains($URLPATTERN)) { return $false }
	else {
		Write-Log("Matched a url pattern")
		
		# Parse the url for the different values
		$parsedUrl = Parse-Url($originalEmailTextDecoded)
		
		# Set our variables
		$url = $parsedUrl[0]
		$webUrl = $parsedUrl[1]
		$listPath = $parsedUrl[2]
		$emailItemId = $parsedUrl[3]
		
		Write-Log("url: " + $url)
		Write-Log("webUrl: " + $webUrl)
		Write-Log("listPath: " + $listPath)
		Write-Log("itemId: " + $emailItemId)
		
		# Get context to pass to the functions
		# Bind to site collection
		$context = New-Object Microsoft.SharePoint.Client.ClientContext($webUrl)
		$context.Credentials = $spoCred
		$context.ExecuteQuery()
	
		Write-Log("Got Context: " + $context.url)

		# Get the list item
		$spListItem = Get-ListItem $context $webUrl $listPath $emailItemId
		
		Write-Log("Title in Process-Item: " + $spListItem["Title"])

		$assignedTo = $spListItem["AssignedTo"].LookupValue
		Write-Log("Assigned To: $assignedTo")	
		
		# If the email is from the person who assigned the task, Update List Item 
		# NOTE: If you want to check that the user's email matches who it was assigned to for security,
		#		uncomment below. Just note that tasks assigned to groups will fail if this is undone.
		#if ($assignedTo -eq $($emailItem.From.Name))
		#{
		Write-Log("Updating List Item: " + $spListItem["Title"])
		Update-ListItem $context $spListItem $result $emailItem
		Write-Log("Item " + $result)
		#}
        #else 
        #{
        #    $isValid = $false
        #}
	} 
	
	return $isValid
}

##########################################################
# Get the folder IDs for the various folders
##########################################################
Function Get-Folder-Ids($findResults)
{
	# Loop through each folder, find ours, and grab the Ids
	foreach ($f in $findResults)
	{
		Write-Log("Folder: " + $f.DisplayName)
	
		if ($f.DisplayName -eq $EMAILINBOXFOLDER)
		{
			Write-Log("Folder Name: $($f.DisplayName)") # -- Folder ID: $($f.Id)"
			$folderId = $f.Id
		}

		if ($f.DisplayName -eq $EMAILPROCESSEDFOLDER)
		{
			Write-Log("Processed Folder Name: $($f.DisplayName)") # -- Folder ID: $($f.Id)"
			$folderIdProcessed = $f.Id
		}

		if ($f.DisplayName -eq $EMAILNOTPROCESSEDFOLDER)
		{
			Write-Log("Not Processed Folder Name: $($f.DisplayName)") # -- Folder ID: $($f.Id)"
			$folderIdNotProcessed = $f.Id
		}
	}
	
	#Create an hashtable variable 
    [hashtable]$folderIds = @{} 
	$folderIds.folderId = $folderId
	$folderIds.folderIdProcessed = $folderIdProcessed
	$folderIds.folderIdNotProcessed = $folderIdNotProcessed
	
	# Return the IDs
	return $folderIds
}


##########################################################
# Loop through all the emails and process them
##########################################################
function Process-Email-Approvals
{
	Write-Log("Starting script...")
	# Get all the folders
	$findResults = $service.FindFolders([Microsoft.Exchange.Webservices.Data.WellKnownFolderName]::MsgFolderRoot, $view)

	Write-Log("Getting Folder IDs")
	# Get the folder IDs for the Incoming, Processed and Not Processed items
	$folderIds = Get-Folder-Ids $findResults
	$folderId = $folderIds.folderId
	$folderIdProcessed = $folderIds.folderIdProcessed
	$folderIdNotProcessed = $folderIds.folderIdNotProcessed

	Write-Log("folderId: " + $folderId)
	Write-Log("folderIdProcessed: " + $folderIdProcessed)
	Write-Log("folderIdNotProcessed: " + $folderIdNotProcessed)
	
	Write-Log("Finding Results")
	# Get all the items in the Incoming folder
	$findResults = $service.FindFolders($folderId, $view)
		
	Write-Log("Looping through folders")
	# Loop through each item in the folder and process it.
	do 
	{ 
		Write-Log("Retrieving ItemView")
		# Set what we want to retrieve from the folder. This will grab the first $pagesize emails
		$view = New-Object Microsoft.Exchange.WebServices.Data.ItemView($numOfEmailsToRead,$index) 
		
		Write-Log("Retrieving data from folder")
		# Retrieve the data from the folder 
		$findResults = $service.FindItems($folderId,$view)

		Write-Log("Looping through emails")
		foreach ($emailItem in $findResults.Items)
		{
			Write-Log("Processing Item: " + $($emailItem.Subject))
			$isValid = Process-Item($emailItem)
			Write-Log("isValid: " + $isValid)
			
			# set email to and body
			$body = $emailItem.Body

			# if successful, move to the processed folder
			if ($isValid -eq $true)
			{
				Write-Log("Successfully processed item " + $($emailItem.Subject))
				$null = $emailItem.Move($folderIdProcessed)
			}
			# else send a note to IT to look into it
			else 
			{
				Write-Log("Failed to process item: " + $($emailItem.Subject))
                
				$to = $emailItem.From.Address
                $cc = $toNotProcessed

                $subject = "ERROR - NOT PROCESSED: " + $emailItem.Subject

                Write-Log("Sending to: " + $to)
                Write-Log("cc: " + $cc)
				
				Send-MailMessage `
					-To $to `
                    -Cc $cc `
					-Subject $subject `
					-Body $body `
					-UseSsl `
					-Port 587 `
					-SmtpServer 'smtp.office365.com' `
					-From $UserEmail `
					-Credential $credEmail
			
				$null = $emailItem.Move($folderIdNotProcessed)
			}
			
			Write-Log("")
			Write-Log("____________________________________________________")
			Write-Log("")
		} 
		# Increment $index to next block of emails
		$index += $numOfEmailsToRead
	} while ($findResults.MoreAvailable) # Do/While there are more emails to retrieve
}	

# Process all new emails
Process-Email-Approvals 
