<#
    .SYNOPSIS
        This function is used to export the permissions of a folder and its subfolders to a CSV file.

    .DESCRIPTION
        This function takes a path to a folder as input and outputs a CSV file. It can either export the permissions 
		of the specified folder or include its subfolders as well. It can also filter away inherited permissions to 
		only include directly assigned permissions.

    .PARAMETER FolderPath
        This string parameter is a path to a folder. This folder becomes the target of the script and its permissions will 
		be exported to a CSV. This can be an absolute or relative path. By default, it is set to the current directory.
    
    .PARAMETER OutputFile
        This string parameter is used to specify file name of the output CSV file. This can be an absolute or relative path. 
		By default it outputs a CSV file in the same folder called Permissions.csv  

    .PARAMETER Recurse
        This switch paramether is used to flag whether the subfolders of the FolderPath will be included in the output. 
		Once this flag is set to true, it will recursively traverse all folders until the leaf folders. If unspecified, 
		only the permissions of the specified FolderPath is included.

    .PARAMETER IncludeInheritedRights
        This switch paramether is used to flag whether the inherited rights will be included in the output. If not specified 
		only directly assigned permissions are included.

    .INPUTS
        

    .OUTPUTS
        

    .EXAMPLE
        Export-FolderPermissionCSV
        
        This example outputs the permissions of the current folder (excluding subfolders) to .\Permissions.csv.

    .EXAMPLE
        Export-FolderPermissionCSV -FolderPath C:\windows\system32 -OutputFile .\system32-permissions.csv

        This example outputs the permissions of the specified FolderPath to the specified OutputFile
    
    .EXAMPLE
        Export-FolderPermissionCSV -FolderPath C:\windows\system32 -OutputFile .\system32-permissions.csv -Recurse

        This example outputs the permissions of the specified FolderPath and its subfolders to the specified OutputFile.

	.EXAMPLE
        Export-FolderPermissionCSV -FolderPath C:\windows\system32 -OutputFile .\system32-permissions.csv -IncludeInheritedRights

        This example outputs the directly assigned permissions of the specified FolderPath to the specified OutputFile.

    .LINK
        
#>

function Export-FolderPermissionCSV {

	param(

		# Ensure that the specified folder path exists.
		[ValidateScript({Test-Path $_})]
		[string] $FolderPath = ".\",

		# Ensure that the specified output path is valid.
		[ValidateScript({(Test-Path $_ -IsValid) -and ($_.ToLower().EndsWith(".csv"))})]
		[string] $OutputFile = ".\Permissions.csv", 

		[switch] $Recurse,

		[switch] $IncludeInheritedRights
	)

	# Hashtables of known FileSystemRights 
	$accessMask = [ordered] @{
		[uint32]'0x80000000' = 'GenericRead'
		[uint32]'0x40000000' = 'GenericWrite'
		[uint32]'0x20000000' = 'GenericExecute'
		[uint32]'0x10000000' = 'GenericAll'
		[uint32]'0x02000000' = 'MaximumAllowed'
		[uint32]'0x01000000' = 'AccessSystemSecurity'
		[uint32]'0x00100000' = 'Synchronize'
		[uint32]'0x00080000' = 'WriteOwner'
		[uint32]'0x00040000' = 'WriteDAC'
		[uint32]'0x00020000' = 'ReadControl'
		[uint32]'0x00010000' = 'Delete'
		[uint32]'0x00000100' = 'WriteAttributes'
		[uint32]'0x00000080' = 'ReadAttributes'
		[uint32]'0x00000040' = 'DeleteChild'
		[uint32]'0x00000020' = 'Execute/Traverse'
		[uint32]'0x00000010' = 'WriteExtendedAttributes'
		[uint32]'0x00000008' = 'ReadExtendedAttributes'
		[uint32]'0x00000004' = 'AppendData/AddSubdirectory'
		[uint32]'0x00000002' = 'WriteData/AddFile'
		[uint32]'0x00000001' = 'ReadData/ListDirectory'
	}

	$simplePermissions = [ordered] @{
		[uint32]'0x1f01ff' = 'FullControl'
		[uint32]'0x0301bf' = 'Modify'
		[uint32]'0x0200a9' = 'ReadAndExecute'
		[uint32]'0x02019f' = 'ReadAndWrite'
		[uint32]'0x020089' = 'Read'
		[uint32]'0x000116' = 'Write'
	}

	Write-Host "Reading permissions for $folder..."
	$report = @()
	$file = @()
	
	# Retrieve permissions of the FolderPath
	$curDir = Get-Item $folder
	$acl = $curDir | Get-Acl -Exclude *.*

	# Add the folder path attribute to each of the ACL entries
	$path = $acl.path.replace("Microsoft.PowerShell.Core\FileSystem::","") 
	Write-Host "Processing acl for $($path)..."
	$permissions = $acl.access | ForEach-Object { $_ | `
	Add-Member -MemberType NoteProperty -Name Folder -Value $path -PassThru}
	$report += $permissions

	# Include subfolders if Recurse flag is included
	if($Recurse) {
		$items = Get-ChildItem $folder -recurse -directory	
			
		foreach ($item in $items) {
			$acl = $item | Get-Acl -Exclude *.*
			$path = $acl.path.replace("Microsoft.PowerShell.Core\FileSystem::","")
			Write-Host "Processing acl for $($path)..."
			$permissions = $acl.access | ForEach-Object {
				$_ | Add-Member -MemberType NoteProperty -Name Folder -Value $path -PassThru
			}
			$report += $permissions
		}
	}

	# Run through all ACL entries based on the presence of the IncludeInheritedRights flag 
	Write-Host "Start Processing list of all acl"
	$report | ForEach-Object {
		if($_.Folder -ne $Null -and ($_.IsInherited -ne "TRUE" -or $IncludeInheritedRights))
		{
			$folder = $_.Folder
			Write-Host "Adding" $folder
			$FileSystemRights = $_.FileSystemRights							
			
			Write-Host "Adding user" $_.IdentityReference
			$newobj = new-object system.object
			$newobj | Add-Member -Type NoteProperty -Name Folder -Value $folder
			$newobj | Add-Member -Type NoteProperty -Name IdentityReference -Value $_.IdentityReference
		
			$FileSystemRightsValue = $FileSystemRights.value__
			
			# Convert FileSystemRights to readable text
			$permissions = @()
			$permissions += $simplePermissions.Keys | ForEach-Object {
				if (($FileSystemRightsValue -band $_) -eq $_) {
				$simplePermissions[$_]
				$FileSystemRightsValue = $FileSystemRightsValue -band (-bnot $_)
				}
			}

			$permissions += $accessMask.Keys | Where-Object { $FileSystemRightsValue -band $_ } `
				| ForEach-Object { $accessMask[$_] }

			[string] $permissionString = ""
			foreach($item in $permissions) {
				$permissionString = $permissionString + $item + ","
			}

			if($permissionString -ne "") {
				$permissionString.Substring(0, $permissionString.Length - 1)
			}

			$newobj | Add-Member -Type NoteProperty -Name FileSystemRights -Value $permissionString
			$newobj | Add-Member -Type NoteProperty -Name IsInherited -Value $_.IsInherited
			$newobj | Add-Member -Type NoteProperty -Name InheritanceFlags $_.InheritanceFlags.ToString().Replace(" ","")
			$newobj | Add-Member -Type NoteProperty -Name PropagationFlags $_.PropagationFlags.ToString().Replace(" ","")

			$file += $newobj	
		}
	}
	Write-Host "Exporting $OutputFile..."
	$file | Export-CSV $OutputFile -NoTypeInformation
	Write-Host "The command completed successfully."
}


