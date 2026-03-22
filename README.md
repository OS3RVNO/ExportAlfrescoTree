# ExportAlfrescoTree

PowerShell script to recursively download an Alfresco folder tree, recreate the
same structure locally, and optionally generate a ZIP archive at the end.

## Improvements Included

- No hardcoded credentials in the script.
- Explicit parameters for URL, root node, destination path, and ZIP output.
- Support for Alfresco API pagination.
- Automatic retry logic for HTTP requests and downloads.
- Safe handling of invalid Windows file names.
- Creation of empty folders during recursive traversal.
- Clear final summary with useful counters.
- Improved console UI with banner, progress reporting, and readable hierarchical logs.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- HTTP/HTTPS access to an Alfresco instance
- Valid credentials for the Alfresco public REST API

## Main File

- `Export-AlfrescoFolderTree.ps1`: main script

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

## Execution Experience

During execution, the script shows:

- a startup banner with the current session settings
- colorized logs for folders, files, skipped items, errors, and successful downloads
- a progress bar during export
- a cleaner final run summary

## Main Parameters

- `-AlfrescoUrl`: base URL of the Alfresco instance
- `-RootNodeId`: node ID of the folder to export
- `-DestinationPath`: local destination folder
- `-Credential`: `PSCredential` object
- `-ZipFilePath`: optional final ZIP archive path
- `-PageSize`: number of items requested per API page
- `-MaxRetryCount`: retry count for transient failures
- `-SkipExisting`: skip files that already exist in the destination path

## Operational Notes

- The script uses Basic authentication against the Alfresco public REST API.
- File names containing invalid Windows characters are sanitized automatically.
- If `-ZipFilePath` is specified, any existing ZIP at that location is overwritten.
- The ZIP file must not be created inside `-DestinationPath`, otherwise compression is blocked.

## Possible Future Enhancements

- OAuth or token-based authentication support
- Structured file logging
- Filtering by file extension or date
- Automated tests and PowerShell linting
