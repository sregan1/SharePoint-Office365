########################################################################
##
## Update a SharePoint list from Active Directory to get all new hires
## Run daily as a scheduled task
## 
## Created: 12/9/2020
## Created by:  Sean Regan
##
########################################################################


# SharePoint site to add users to
$SiteUrl = "https://vivityconsulting.sharepoint.com/sites/NewHires"
# Name of the list to add users to
$ListName = "New Hires"

Start-Transcript -Path .\Logs\NewHireList$(get-date -f yyyy-MM-dd_hh_mm).txt

Connect-PnPOnline -Url $SiteUrl -Credentials (Get-Credential)

# Get the users in the past day
$When = ((Get-Date).AddDays(-1)).Date

Write-Host "Getting New AD Users..."
$Users = Get-ADUser -Filter {whenCreated -ge $When} -Properties Name,mail,Title,SamAccountName,AccountExpirationDate,Manager,Created,Department,whenCreated | select Name,Department,@{N='Manager';E={(Get-ADUser $_.Manager).Name}},@{N='ManagerEmail';E={(Get-ADUser -Properties mail $_.Manager).mail}},Created,Title,mail
Write-Host "Retrieved $($Users.Count) AD Users"

if ($Users.Count -gt 0)
{
    # Get a list of all New Hires
    Write-Host "Getting all users in New Hire list..."
    $AllNewHires = New-Object Collections.Generic.List[string]
    $NewHires = Get-PnPListItem -List $ListName -Fields "Title","NewHire","ol_Department","Manager","GUID","LookupId"

    foreach ($NewHire in $NewHires)
    {
        $user = Get-PnPUser -Identity $NewHire["NewHire"].LookupId
        $email = $user.Email
        $username = $user.LoginName
        $fullname = $user.Title

        $Manager = Get-PnPUser -Identity $NewHire["Manager"].LookupId
        $ManagerEmail = $Manager.Email
        $ManagerLogin = $Manager.LoginName
        $ManagerName = $Manager.Title

        $AllNewHires.Add($fullname)
    }

    Write-Host "Got $($AllNewHires.Count) in New Hire List"

    Write-Host "Adding users..."

	# Add all the users to the SharePoint list
    foreach ($User in $Users)
    {

        Write-Host "Name: "$User.Name
        Write-Host "Email: "$User.mail
        Write-Host "Title: "$User.Title
        Write-Host "Department: "$User.Department
        Write-Host "Manager: "$User.Manager
        Write-Host "Manager Email: "$User.ManagerEmail
        Write-Host "Created: "$User.Created

        if ($AllNewHires -notcontains $($User.Name))
        {
            if (($($User.Name) -notlike "adm-*") -and ($($User.Name) -notlike "test-*"))
            {
                Write-Host "Adding $($User.Name)"

                # Values - Use internal names of the fields separated by semicolon (;) 
                Add-PnPListItem -List $ListName -Values @{"Title" = $User.Title; "NewHire" = "$($User.mail)"; "ol_Department" = $User.Department; "Manager" = "$($User.ManagerEmail)"} 

                Write-Host "Successfully Added $($User.Name)"
            }
            else
            {
                Write-Host "*** Skipping the admin account: $($User.Name)"
            }
        }
        else
        {
            Write-Host "*** The list contains $($User.Name) so we're skipping it"
        }

        Write-Host ""
    }
}

Write-Host "Fin"

Stop-Transcript
 
Disconnect-PnPOnline