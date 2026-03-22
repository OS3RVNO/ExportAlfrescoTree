# Powershell

Script PowerShell per scaricare in modo ricorsivo una cartella Alfresco, ricreare
l'alberatura locale e, se richiesto, generare anche un archivio ZIP finale.

## Cosa e stato migliorato

- Nessuna credenziale hardcoded nel file.
- Parametri espliciti per URL, nodo radice, destinazione e ZIP.
- Supporto alla paginazione dell'API Alfresco.
- Retry automatico per richieste HTTP e download.
- Gestione dei nomi file non validi su Windows.
- Creazione delle cartelle vuote durante la ricorsione.
- Riepilogo finale con contatori utili.
- Console UI colorata con banner, avanzamento e log gerarchico piu leggibile.

## Requisiti

- Windows PowerShell 5.1 o PowerShell 7+
- Accesso HTTP/HTTPS a un'istanza Alfresco
- Credenziali valide per l'API REST pubblica di Alfresco

## File principali

- `Export-AlfrescoFolderTree.ps1`: script principale

## Esempio rapido

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

## Esperienza di esecuzione

Durante il run lo script mostra:

- banner iniziale con configurazione della sessione
- log colorato per cartelle, file, skip, errori e successi
- progress bar di avanzamento
- riepilogo finale piu leggibile

## Parametri principali

- `-AlfrescoUrl`: URL base dell'istanza Alfresco
- `-RootNodeId`: node id della cartella da esportare
- `-DestinationPath`: cartella locale di destinazione
- `-Credential`: oggetto `PSCredential`
- `-ZipFilePath`: opzionale, crea un file ZIP finale
- `-PageSize`: numero di elementi richiesti per pagina API
- `-MaxRetryCount`: numero di retry in caso di errore temporaneo
- `-SkipExisting`: salta i file gia presenti nel path di destinazione

## Note operative

- Lo script usa autenticazione Basic verso l'API REST pubblica di Alfresco.
- Se un nome file contiene caratteri non validi per Windows, viene sanificato.
- Se viene specificato `-ZipFilePath`, un eventuale ZIP esistente viene sovrascritto.
- Il file ZIP non deve stare dentro `-DestinationPath`, altrimenti la compressione viene bloccata.

## Miglioramenti futuri possibili

- Supporto OAuth o token-based authentication
- Log su file strutturato
- Filtri per estensione o data
- Test automatici e lint PowerShell
