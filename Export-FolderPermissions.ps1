#Pre-requisite: PowerShell version 3
#               folders.txt input file in the same directory as where the script is stored

function Export-FolderPermissionCSV {

	param(
		# Parameter help description
		[ValidateScript({Test-Path $_})]
		[string] $FolderPath = ".\",

		[bool] $Recurse = $false,

		[ValidateScript({Test-Path $_})]
		[string] $OutputFile = ".\Permissions.csv"
	)

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

	$count = 0
	foreach ($folder in $FolderPath) {

		Write-Host "Getting permissions for " $folder
		$count++
		$report = @()
		$file = @()
		$filename = ".\"+$count+'_permissions.csv'
		
		$curDir = Get-Item $folder
		$acl = $curDir | Get-Acl -Exclude *.*
		$path = $acl.path.replace("Microsoft.PowerShell.Core\FileSystem::","")
		Write-Host "Processing acl for $($path)..."
		$permissions = $acl.access | ForEach-Object { $_ | `
		Add-Member -MemberType NoteProperty -Name Folder -Value $path -PassThru}
		$report += $permissions

		if($Recurse) {
			$items = Get-ChildItem $folder -recurse -directory	
				
			foreach ($item in $items) {
				$acl = $item | Get-Acl -Exclude *.*
				$path = $acl.path.replace("Microsoft.PowerShell.Core\FileSystem::","")
				Write-Host "Processing acl for $($path)..."
				$permissions = $acl.access | ForEach-Object {$_ | `
				Add-Member -MemberType NoteProperty -Name Folder -Value $path -PassThru}
				$report += $permissions
			}
		}

		Write-Host "Start Processing list of all acl"
		$report | % {
			if($_.Folder -ne $Null -and $_.IsInherited -ne "TRUE")
			#if($_.Folder -ne $Null)
			{
				$folder = $_.Folder
				Write-Host "Adding" $folder
				$FileSystemRights = $_.FileSystemRights							
				
				Write-Host "Adding user" $_.IdentityReference
				$newobj = new-object system.object
				$newobj | Add-Member -Type NoteProperty -Name Folder -Value $folder
				$newobj | Add-Member -Type NoteProperty -Name IdentityReference -Value $_.IdentityReference
			
				$FileSystemRightsValue = $FileSystemRights.value__
				
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
		Write-Host "Exporting" $OutputFile
		$file | Export-CSV $OutputFile -NoTypeInformation
	}
}


