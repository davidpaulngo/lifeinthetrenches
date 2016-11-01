<#
    .SYNOPSIS
        This function is used to convert a CSV file into an AzureRM template parameters file/s.

    .DESCRIPTION
        This function takes an input CSV file and for each line it extracts the properties 
        and wraps it into an Azure Resource Management template parameter file in JSON format. 
        By default, the multiple output files are produced but it can also produce a single output file. 
        This function is useful in scenarios where it is necessary to provision multiple resources 
        with the same set of parameters (with different values) in Azure.

    .PARAMETER CSVFile
        This parameter is a file path to a CSV file that will be used as the source object for the function. 
        This parameter is mutually exclusive to the "InputObject" parameter.
    
    .PARAMETER OutputPrefix
        This parameter is used to specify the prefix prepended to the output files. If there are multiple output files, 
        this prefix is appended with a running number that starts from 1. 

    .PARAMETER MergeOutput
        This paramether is used to determine whether there will be multiple output files or a single output file. By default, 
        multiple output files are produced.

    .PARAMETER ObjectLabel
        This paramether is used to determine what the name of the parameter will be if there is only a single output file.

    .INPUTS
        This function can receive a file path from the pipeline.

    .OUTPUTS
        This function returns a collection of the filenames the JSON files produced.

    .EXAMPLE
        ConvertTo-AzureRmParametersJSON -CSVFile .\TestFile.csv
        
        This example shows the usage of the function with a CSV file as input.

    .EXAMPLE
        ConvertTo-AzureRmParametersJSON -CSVFile .\TestFile.csv -OutputPrefix "test-"

        This example shows the usage of the function with a CSV file as input while also 
        configuring the prefix of output files.
    
    .EXAMPLE
        ConvertTo-AzureRmParametersJSON -CSVFile .\TestFile.csv -OutputPrefix "OutputFile" -MergeOutput $true

        This example shows the usage of the function with a CSV file as input while also 
        merging the output to a single file and specifying the file name.

    .LINK
        AzureRM Template Authoring: https://azure.microsoft.com/en-us/documentation/articles/resource-group-authoring-templates/
#>
function ConvertTo-AzureRmParametersJSON {

    Param (
        [Parameter(Mandatory=$true, ParameterSetName="CSVFile", ValueFromPipeline=$true)]
        [ValidateScript({Test-Path $_})]
        [string] $CSVFile,

        [Parameter(ParameterSetName="CSVFile")]
        [string] $OutputPrefix = "item-",

        [Parameter(ParameterSetName="CSVFile")]
        [bool] $MergeOutput = $false,

        [Parameter(ParameterSetName="CSVFile")]
        [ValidateScript({$_.length -gt 0})]
        [string] $ObjectLabel = "Objects"
    )
    
    try {
        $sourceObj = Import-Csv $CSVFile
    }
    catch [System.Exception] {
         
    }

    $outputFiles = @()
    $count = 1
    if($sourceObj) {

        if($MergeOutput) {

            # Create new PowerShell object to store JSON data
            $newObj = New-Object System.Object

            # Add standard properties of the parameter file to the object
            $newObj | Add-Member -Type NoteProperty -Name "`$schema" -Value `
                "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
            $newObj | Add-Member -Type NoteProperty -Name "contentVersion" -Value `
                "1.0.0.0"

            $values = @()
            # Evaluate each line item in the CSV
            foreach($item in $sourceObj) {
                $params = @{}

                $item.PsObject.Properties | ForEach-Object {            
                    $name = $_.Name
                    $value = $_.Value
                    $params.Add($name,$value)
                }

                $values += $params
            }
            
            $valueWrapper = @{"value" = $values}
            $paramWrapper = @{$ObjectLabel = $valueWrapper}
            
            # Add "parameters" property to the object
            $newObj | Add-Member -Type NoteProperty -Name "parameters" -Value $paramWrapper

            # Build output file name
            $fileName = "$OutputPrefix.json"
            # Convert the PowerShell object to JSON and write the output file
            ConvertTo-Json -InputObject $newObj -Depth 20 | Out-File $fileName

            $outputFiles += $fileName
        }
        else {
            # Evaluate each line item in the CSV
            foreach($item in $sourceObj) {

                # Create new PowerShell object to store JSON data
                $newObj = New-Object System.Object

                # Add standard properties of the parameter file to the object
                $newObj | Add-Member -Type NoteProperty -Name "`$schema" -Value `
                    "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
                $newObj | Add-Member -Type NoteProperty -Name "contentVersion" -Value `
                    "1.0.0.0"
                
                # Evaluate each property of the CSV line item
                $params = @{}
                $item.PsObject.Properties | ForEach-Object {            
                    $name = $_.Name
                    $value = $_.Value
                    
                    $valueObj = @{}
                    $valueObj.Add("value",$value)

                    $params.Add($name,$valueObj)
                }

                # Add "parameters" property to the object
                $newObj | Add-Member -Type NoteProperty -Name "parameters" -Value $params
                
                # Build output file name
                $fileName = $OutputPrefix + "$count.json"

                # Convert the PowerShell object to JSON and write the output file
                ConvertTo-Json -InputObject $newObj | Out-File $fileName
                
                $outputFiles += $fileName
                $count++
            }
        }
        

        # Return data of the script
        $outputFiles
    }
    else {
        Write-Host "ERROR: Input CSV is null" -ForegroundColor Red
    }
} 