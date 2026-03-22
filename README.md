# ExportAlfrescoTree

<p align="center">
  <strong>Export an Alfresco folder tree to a local Windows path with preserved structure, retry logic, and optional ZIP packaging.</strong>
</p>

<p align="center">
  <img alt="PowerShell 5.1+" src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white">
  <img alt="Platform Windows" src="https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows&logoColor=white">
  <img alt="License Unlicense" src="https://img.shields.io/badge/License-Unlicense-blue.svg">
</p>

`ExportAlfrescoTree` is a focused PowerShell utility for downloading a complete
folder tree from Alfresco through the public REST API, recreating the same
structure locally, and optionally generating a ZIP archive for handoff or backup.

## Why This Repository

Use this project when you need to:

- export a full Alfresco folder hierarchy without manually downloading files one by one
- preserve the original folder layout on disk
- retry transient HTTP failures automatically
- avoid hardcoded credentials in the script
- generate a clean ZIP package after the export finishes

## Features

- parameterized script with no embedded credentials
- recursive traversal of Alfresco folders
- support for paginated API responses
- optional ZIP creation after download
- invalid Windows file name sanitization
- empty folder creation during traversal
- skip-existing mode for repeatable runs
- colorized console UI with progress reporting and final summary

## Main File

- `Export-AlfrescoFolderTree.ps1`

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- network access to an Alfresco instance
- valid credentials for the Alfresco public REST API

## Quick Start

```powershell
$credential = Get-Credential

.\Export-AlfrescoFolderTree.ps1 `
    -AlfrescoUrl "https://alfresco-site.example" `
    -RootNodeId "workspace://SpacesStore/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -DestinationPath "C:\Temp\AlfrescoExport" `
    -Credential $credential `
    -ZipFilePath "C:\Temp\AlfrescoExport.zip" `
    -Verbose
```

## Example Console Output

```text
==========================================================================================
                                 ALFRESCO FOLDER EXPORT
                Recursive download with local tree and optional ZIP archive
==========================================================================================

[CONFIGURATION]
------------------------------------------------------------------------------------------
URL:            https://alfresco-site.example
Root Node:      workspace://SpacesStore/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Destination:    C:\Temp\AlfrescoExport
ZIP Output:     C:\Temp\AlfrescoExport.zip
Page Size:      100
Retries:        3
Skip Existing:  False

[TRANSFER]
------------------------------------------------------------------------------------------
[INFO] Starting recursive export from Alfresco root node.
[DIR ] Contracts
  [FILE] contract-001.pdf
    [OK  ] Saved to: C:\Temp\AlfrescoExport\Contracts\contract-001.pdf
  [FILE] contract-002.pdf
    [SKIP] Existing file skipped: contract-002.pdf

==========================================================================================
                                        RUN SUMMARY
------------------------------------------------------------------------------------------
Folders:        3
Files Found:    12
Downloaded:     10
Skipped:        2
Errors:         0
==========================================================================================
```

## Parameters

| Parameter | Description |
| --- | --- |
| `-AlfrescoUrl` | Base URL of the Alfresco instance |
| `-RootNodeId` | Node ID of the folder to export |
| `-DestinationPath` | Local destination folder |
| `-Credential` | `PSCredential` object used for Basic authentication |
| `-ZipFilePath` | Optional path for the final ZIP archive |
| `-PageSize` | Number of items requested per API page |
| `-MaxRetryCount` | Retry count for transient failures |
| `-SkipExisting` | Skip files that already exist in the destination path |

## Operational Notes

- The script uses Basic authentication against the Alfresco public REST API.
- File names containing invalid Windows characters are sanitized automatically.
- If `-ZipFilePath` is specified, any existing ZIP at that location is overwritten.
- The ZIP file must not be created inside `-DestinationPath`.

## Roadmap

- OAuth or token-based authentication support
- structured file logging
- filtering by file extension or date
- automated tests and PowerShell linting

## License

This repository is released under the Unlicense. See `LICENSE` for details.
