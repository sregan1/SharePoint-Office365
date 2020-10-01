######################################################################
# This script copies all of the views from one list to another list
# 9/30/2020 Sean Regan
######################################################################

# Url to the admin site
$siteUrl = "https://vivity.sharepoint.com"

# The list where we want to copy all of the views
$listWithViewsToCopy = "Banana"

# The list name to copy the views to
$listToCopyTo = "Pineapple"

Write-Host "Connecting to PnP..."
Connect-PnPOnline -Url $siteUrl -Credential (Get-credential)

# Get all the views for the list
$viewsToCopy = Get-PnPView -List $listWithViewsToCopy -Includes "ViewQuery","ViewType","ViewData","ViewJoins","ViewProjectedFields","RowLimit","Paged"

# Loop through each view and create it in the new list
foreach ($view in $viewsToCopy)
{
	Write-Host "Adding View: "$view.Title
	
	# Loop through all fields and create an array
	$fields = [System.Collections.ArrayList]::new()    
	foreach ($field in $view.ViewFields)
	{
		[void]$fields.Add($field)	
	}

	# Add the new view
	Add-PnPView -List $listToCopyTo -Title $view.Title -Fields $fields -Query $view.ViewQuery -ViewType $view.ViewType -RowLimit $view.RowLimit
} 
