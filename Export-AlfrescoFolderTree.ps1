#requires -Version 5.1

<#
.SYNOPSIS
Downloads an Alfresco folder tree and optionally creates a ZIP archive.

.DESCRIPTION
Uses the Alfresco public REST API to enumerate a node recursively, recreate the
folder structure locally, download all files, and optionally compress the result.

.EXAMPLE
$credential = Get-Credential
.\Export-AlfrescoFolderTree.ps1 `
    -AlfrescoUrl "https://alfresco-site.example" `
    -RootNodeId "workspace://SpacesStore/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -DestinationPath "C:\Temp\AlfrescoExport" `
    -Credential $credential `
    -ZipFilePath "C:\Temp\AlfrescoExport.zip" `
    -Verbose
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AlfrescoUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RootNodeId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$Credential,

    [string]$ZipFilePath,

    [ValidateRange(1, 1000)]
    [int]$PageSize = 100,

    [ValidateRange(0, 10)]
    [int]$MaxRetryCount = 3,

    [switch]$SkipExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Stats = [ordered]@{
    FoldersVisited  = 0
    FilesDiscovered = 0
    FilesDownloaded = 0
    FilesSkipped    = 0
    Errors          = 0
}

$script:UiWidth = 90
$script:ProgressId = 1
$script:ResolvedDestinationPath = $null

function Initialize-Ui {
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
    } catch {
        $width = 90
    }

    if ($width -lt 70) {
        $width = 70
    }

    if ($width -gt 110) {
        $width = 110
    }

    $script:UiWidth = $width
}

function Write-UiRule {
    param(
        [char]$Character = '=',
        [ConsoleColor]$Color = [ConsoleColor]::DarkCyan
    )

    Write-Host (($Character.ToString()) * $script:UiWidth) -ForegroundColor $Color
}

function Write-UiCenteredText {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    $content = $Text.Trim()
    if ([string]::IsNullOrWhiteSpace($content)) {
        Write-Host ''
        return
    }

    $padding = [Math]::Max([Math]::Floor(($script:UiWidth - $content.Length) / 2), 0)
    Write-Host ((' ' * $padding) + $content) -ForegroundColor $Color
}

function Write-UiBanner {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Subtitle
    )

    Write-Host ''
    Write-UiRule -Character '=' -Color DarkCyan
    Write-UiCenteredText -Text $Title -Color Cyan
    Write-UiCenteredText -Text $Subtitle -Color Gray
    Write-UiRule -Character '=' -Color DarkCyan
}

function Write-UiSection {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ''
    Write-Host ("[{0}]" -f $Title.ToUpperInvariant()) -ForegroundColor Yellow
    Write-UiRule -Character '-' -Color DarkGray
}

function Write-UiField {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Value,

        [ConsoleColor]$LabelColor = [ConsoleColor]::DarkGray,
        [ConsoleColor]$ValueColor = [ConsoleColor]::White
    )

    $prefix = ('{0,-15}' -f ($Label + ':'))
    Write-Host -NoNewline $prefix -ForegroundColor $LabelColor
    Write-Host $Value -ForegroundColor $ValueColor
}

function Write-UiMessage {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL', 'DIR', 'FILE', 'SKIP')]
        [string]$Kind,

        [Parameter(Mandatory)]
        [string]$Message,

        [int]$Depth = 0
    )

    $color = switch ($Kind) {
        'INFO' { 'Gray' }
        'OK'   { 'Green' }
        'WARN' { 'Yellow' }
        'FAIL' { 'Red' }
        'DIR'  { 'Cyan' }
        'FILE' { 'White' }
        'SKIP' { 'DarkYellow' }
    }

    $indent = '  ' * [Math]::Max($Depth, 0)
    $tag = '[{0}]' -f $Kind.PadRight(4)
    Write-Host ("{0}{1} {2}" -f $indent, $tag, $Message) -ForegroundColor $color
}

function Update-UiProgress {
    param(
        [Parameter(Mandatory)]
        [string]$Status,

        [string]$CurrentOperation
    )

    $summary = 'Downloaded: {0} | Skipped: {1} | Errors: {2}' -f `
        $script:Stats.FilesDownloaded,
        $script:Stats.FilesSkipped,
        $script:Stats.Errors

    if ([string]::IsNullOrWhiteSpace($CurrentOperation)) {
        Write-Progress -Id $script:ProgressId -Activity 'Exporting Alfresco folder tree' -Status $Status -CurrentOperation $summary
        return
    }

    Write-Progress -Id $script:ProgressId -Activity 'Exporting Alfresco folder tree' -Status $Status -CurrentOperation ("{0} | {1}" -f $CurrentOperation, $summary)
}

function Complete-UiProgress {
    Write-Progress -Id $script:ProgressId -Activity 'Exporting Alfresco folder tree' -Completed
}

function Show-RunSummary {
    Write-Host ''
    Write-UiRule -Character '=' -Color DarkGreen
    Write-UiCenteredText -Text 'RUN SUMMARY' -Color Green
    Write-UiRule -Character '-' -Color DarkGreen

    Write-UiField -Label 'Folders' -Value ([string]$script:Stats.FoldersVisited) -ValueColor White
    Write-UiField -Label 'Files Found' -Value ([string]$script:Stats.FilesDiscovered) -ValueColor White
    Write-UiField -Label 'Downloaded' -Value ([string]$script:Stats.FilesDownloaded) -ValueColor Green
    Write-UiField -Label 'Skipped' -Value ([string]$script:Stats.FilesSkipped) -ValueColor Yellow

    $errorColor = if ($script:Stats.Errors -gt 0) { 'Red' } else { 'Green' }
    Write-UiField -Label 'Errors' -Value ([string]$script:Stats.Errors) -ValueColor $errorColor

    if ($script:Stats.Errors -eq 0) {
        Write-Host ''
        Write-UiMessage -Kind OK -Message 'Export completed successfully.'
    } else {
        Write-Host ''
        Write-UiMessage -Kind WARN -Message 'Export completed with one or more errors.'
    }

    Write-UiRule -Character '=' -Color DarkGreen
}

function New-BasicAuthHeader {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credential
    )

    $networkCredential = $Credential.GetNetworkCredential()
    $credentialPair = '{0}:{1}' -f $networkCredential.UserName, $networkCredential.Password
    $encodedCredentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($credentialPair))

    return @{
        Authorization = "Basic $encodedCredentials"
    }
}

function Get-WebCommandCommonParameters {
    $params = @{
        Headers     = $script:Headers
        ErrorAction = 'Stop'
    }

    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $params.UseBasicParsing = $true
    }

    return $params
}

function Get-SafePathSegment {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return '_empty_'
    }

    $invalidChars = [IO.Path]::GetInvalidFileNameChars()
    $safeName = -join ($Name.ToCharArray() | ForEach-Object {
        if ($invalidChars -contains $_) {
            '_'
        } else {
            $_
        }
    })

    $safeName = $safeName.Trim().TrimEnd('.', ' ')

    $reservedNames = @(
        'CON', 'PRN', 'AUX', 'NUL',
        'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
        'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
    )

    $baseName = [IO.Path]::GetFileNameWithoutExtension($safeName).ToUpperInvariant()
    if ($reservedNames -contains $baseName) {
        $safeName = "_$safeName"
    }

    if ([string]::IsNullOrWhiteSpace($safeName)) {
        return '_empty_'
    }

    return $safeName
}

function Get-LocalItemName {
    param(
        [Parameter(Mandatory)]
        [string]$OriginalName,

        [Parameter(Mandatory)]
        [string]$NodeId
    )

    $safeName = Get-SafePathSegment -Name $OriginalName

    if ($safeName -eq $OriginalName) {
        return $safeName
    }

    $baseName = [IO.Path]::GetFileNameWithoutExtension($safeName)
    $extension = [IO.Path]::GetExtension($safeName)

    return '{0}_{1}{2}' -f $baseName, $NodeId, $extension
}

function Invoke-AlfrescoRestMethod {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $attempt = 0

    while ($true) {
        try {
            $uri = '{0}/{1}' -f $script:BaseApiUrl, $RelativePath.TrimStart('/')
            $params = Get-WebCommandCommonParameters
            $params.Uri = $uri
            $params.Method = 'Get'

            return Invoke-RestMethod @params
        } catch {
            if ($attempt -ge $MaxRetryCount) {
                throw
            }

            $attempt++
            Write-Warning ("Request failed ({0}/{1}) for {2}: {3}" -f $attempt, $MaxRetryCount, $RelativePath, $_.Exception.Message)
            Start-Sleep -Seconds ([Math]::Min(2 * $attempt, 10))
        }
    }
}

function Get-AlfrescoChildren {
    param(
        [Parameter(Mandatory)]
        [string]$NodeId
    )

    $allEntries = New-Object System.Collections.Generic.List[object]
    $skipCount = 0
    $hasMoreItems = $true

    while ($hasMoreItems) {
        $relativePath = 'nodes/{0}/children?skipCount={1}&maxItems={2}' -f [uri]::EscapeDataString($NodeId), $skipCount, $PageSize
        $response = Invoke-AlfrescoRestMethod -RelativePath $relativePath
        $currentEntries = @()

        if ($null -ne $response.list -and $null -ne $response.list.entries) {
            $currentEntries = @($response.list.entries)

            foreach ($entry in $currentEntries) {
                [void]$allEntries.Add($entry.entry)
            }
        }

        if ($null -ne $response.list -and $null -ne $response.list.pagination) {
            $hasMoreItems = [bool]$response.list.pagination.hasMoreItems
            $skipCount = [int]$response.list.pagination.skipCount + $currentEntries.Count
        } else {
            $hasMoreItems = $false
        }
    }

    return $allEntries
}

function Save-AlfrescoContent {
    param(
        [Parameter(Mandatory)]
        [string]$NodeId,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    $attempt = 0

    while ($true) {
        try {
            $uri = '{0}/nodes/{1}/content?attachment=true' -f $script:BaseApiUrl, [uri]::EscapeDataString($NodeId)
            $params = Get-WebCommandCommonParameters
            $params.Uri = $uri
            $params.Method = 'Get'
            $params.OutFile = $TargetPath

            Invoke-WebRequest @params | Out-Null
            return
        } catch {
            if (Test-Path -LiteralPath $TargetPath) {
                Remove-Item -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue
            }

            if ($attempt -ge $MaxRetryCount) {
                throw
            }

            $attempt++
            Write-Warning ("Download failed ({0}/{1}) for '{2}': {3}" -f $attempt, $MaxRetryCount, $DisplayName, $_.Exception.Message)
            Start-Sleep -Seconds ([Math]::Min(2 * $attempt, 10))
        }
    }
}

function Download-AlfrescoNodeTree {
    param(
        [Parameter(Mandatory)]
        [string]$NodeId,

        [Parameter(Mandatory)]
        [string]$CurrentPath,

        [int]$Depth = 0
    )

    if (-not (Test-Path -LiteralPath $CurrentPath)) {
        New-Item -ItemType Directory -Path $CurrentPath -Force | Out-Null
    }

    Update-UiProgress -Status 'Scanning folder' -CurrentOperation $CurrentPath
    $children = Get-AlfrescoChildren -NodeId $NodeId

    if ($children.Count -eq 0) {
        Write-Verbose ("No children found for node {0}" -f $NodeId)
        Write-UiMessage -Kind INFO -Message ("Empty folder: {0}" -f (Split-Path -Path $CurrentPath -Leaf)) -Depth $Depth
        return
    }

    foreach ($child in $children) {
        $localName = Get-LocalItemName -OriginalName $child.name -NodeId $child.id
        $localPath = Join-Path -Path $CurrentPath -ChildPath $localName

        if ($child.isFolder) {
            $script:Stats.FoldersVisited++
            Write-UiMessage -Kind DIR -Message $child.name -Depth $Depth

            if (-not (Test-Path -LiteralPath $localPath)) {
                New-Item -ItemType Directory -Path $localPath -Force | Out-Null
            }

            Download-AlfrescoNodeTree -NodeId $child.id -CurrentPath $localPath -Depth ($Depth + 1)
            continue
        }

        $script:Stats.FilesDiscovered++
        Write-UiMessage -Kind FILE -Message $child.name -Depth $Depth
        Update-UiProgress -Status 'Downloading file' -CurrentOperation $child.name

        if ($SkipExisting -and (Test-Path -LiteralPath $localPath)) {
            $script:Stats.FilesSkipped++
            Write-UiMessage -Kind SKIP -Message ("Existing file skipped: {0}" -f $localName) -Depth ($Depth + 1)
            continue
        }

        try {
            Save-AlfrescoContent -NodeId $child.id -TargetPath $localPath -DisplayName $child.name
            $script:Stats.FilesDownloaded++
            Write-UiMessage -Kind OK -Message ("Saved to: {0}" -f $localPath) -Depth ($Depth + 1)
        } catch {
            $script:Stats.Errors++
            Write-UiMessage -Kind FAIL -Message ("Download failed for '{0}': {1}" -f $child.name, $_.Exception.Message) -Depth ($Depth + 1)
        }
    }
}

function Compress-DownloadDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$SourceFolder,

        [Parameter(Mandatory)]
        [string]$DestinationZip
    )

    if (-not (Test-Path -LiteralPath $SourceFolder)) {
        throw "Source folder not found: $SourceFolder"
    }

    $sourceFullPath = [IO.Path]::GetFullPath($SourceFolder)
    $zipFullPath = [IO.Path]::GetFullPath($DestinationZip)
    $sourcePrefix = $sourceFullPath.TrimEnd('\') + [IO.Path]::DirectorySeparatorChar

    if ($zipFullPath.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "DestinationZip cannot be created inside SourceFolder."
    }

    $zipParent = Split-Path -Path $zipFullPath -Parent

    if (-not [string]::IsNullOrWhiteSpace($zipParent) -and -not (Test-Path -LiteralPath $zipParent)) {
        New-Item -ItemType Directory -Path $zipParent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $zipFullPath) {
        Remove-Item -LiteralPath $zipFullPath -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($sourceFullPath, $zipFullPath)
}

$script:Headers = New-BasicAuthHeader -Credential $Credential
$script:BaseApiUrl = '{0}/api/-default-/public/alfresco/versions/1' -f $AlfrescoUrl.TrimEnd('/')

try {
    Initialize-Ui
    $script:ResolvedDestinationPath = [IO.Path]::GetFullPath($DestinationPath)

    Write-UiBanner -Title 'ALFRESCO FOLDER EXPORT' -Subtitle 'Recursive download with local tree and optional ZIP archive'
    Write-UiSection -Title 'Configuration'
    Write-UiField -Label 'URL' -Value $AlfrescoUrl
    Write-UiField -Label 'Root Node' -Value $RootNodeId
    Write-UiField -Label 'Destination' -Value $script:ResolvedDestinationPath
    Write-UiField -Label 'ZIP Output' -Value $(if ($ZipFilePath) { [IO.Path]::GetFullPath($ZipFilePath) } else { 'disabled' })
    Write-UiField -Label 'Page Size' -Value ([string]$PageSize)
    Write-UiField -Label 'Retries' -Value ([string]$MaxRetryCount)
    Write-UiField -Label 'Skip Existing' -Value ([string][bool]$SkipExisting)

    if (-not (Test-Path -LiteralPath $script:ResolvedDestinationPath)) {
        New-Item -ItemType Directory -Path $script:ResolvedDestinationPath -Force | Out-Null
    }

    Write-UiSection -Title 'Transfer'
    Write-UiMessage -Kind INFO -Message 'Starting recursive export from Alfresco root node.'

    Download-AlfrescoNodeTree -NodeId $RootNodeId -CurrentPath $script:ResolvedDestinationPath

    if ($ZipFilePath) {
        Update-UiProgress -Status 'Creating ZIP archive' -CurrentOperation $ZipFilePath
        Compress-DownloadDirectory -SourceFolder $script:ResolvedDestinationPath -DestinationZip $ZipFilePath
        Write-UiMessage -Kind OK -Message ("ZIP created: {0}" -f ([IO.Path]::GetFullPath($ZipFilePath)))
    }

    Complete-UiProgress
    Show-RunSummary
} catch {
    Complete-UiProgress
    Write-UiSection -Title 'Execution Failed'
    Write-UiMessage -Kind FAIL -Message $_.Exception.Message
    throw "Execution failed: $($_.Exception.Message)"
}
