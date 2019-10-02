#Load SharePoint CSOM Assemblies
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
   
#Config Parameters
$SiteURL= "https://vivity.sharepoint.com"
$ListName="Documents"
$NewListURL="NewDocumentsUrl"
 
#Setup Credentials to connect
$Cred = Get-Credential
$Cred = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Cred.UserName,$Cred.Password)
   
Try {
    #Setup the context
    $Ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
    $Ctx.Credentials = $Cred
     
    #Get the List
    $List=$Ctx.web.Lists.GetByTitle($ListName)
    $Ctx.Load($List)
 
    #sharepoint online change library url powershell  
    $List.Rootfolder.MoveTo($NewListURL)
    $Ctx.ExecuteQuery()
 
    #Keep the List name as is
    $List.Title=$ListName
    $List.Update()
    $Ctx.ExecuteQuery()
 
    Write-host -f Green "List URL has been changed!"
}
Catch {
    write-host -f Red "Error changing List URL!" $_.Exception.Message
}
