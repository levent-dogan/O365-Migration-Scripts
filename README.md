# Start-Migration.ps1

> **Staged Exchange + OneDrive migration orchestrator**

A single PowerShell script that

1. creates **staged Exchange Online** migration batches,  
2. registers & launches **SharePoint Migration Tool (SPMT)** jobs to move users’ home-drive data into their individual OneDrives, and  
3. logs every step to both console and timestamped log files.  

The goal: migrate hybrid environments to Microsoft 365 with **one command**, minimal hand-holding, and repeatable, idempotent safety.

---

## Features
- **Idempotent design** – skips endpoint or batch creation if they already exist  
- **CSV-driven** – all user mapping in one file  
- **Module pre-flight checks** – fails fast if EXO, PnP or SPMT modules are missing  
- **Device-code / App auth** – no plain-text passwords  
- **Structured logging** – `logs/Migration-YYYYMMDD-HHmmss.log` (UTC), plus console output  
- **Per-user SPMT JSON generation** – consistent OneDrive moves without GUI clicks  

---

## Prerequisites

| Component | Minimum version |
|-----------|-----------------|
| PowerShell | 5.1 (Windows) / 7.x (Core) |
| Modules | `ExchangeOnlineManagement`<br>`SharePointPnPPowerShellOnline`<br>`Microsoft.SharePoint.MigrationTool.PowerShell` |
| Network | Outbound 443 to Microsoft 365 and Azure AD endpoints |

> **Tip:** run in an elevated session with rights to create migration endpoints and SPO-admin connections.
---
## Quick Start
.\Start-Migration.ps1 `
    -Tenant "contoso.onmicrosoft.com" `
    -CsvPath ".\users-to-migrate.csv" `
    -Endpoint "OnPrem-EndPoint" `
    -BatchName "Stage-001"
    
Progress commands:

Get-MigrationBatch  -Identity Stage-001

Get-SPMTMigrationTask -Status Running

---
## Parameters

| Name         | Required | Description                                                  |
| ------------ | -------- | ------------------------------------------------------------ |
| `-Tenant`    | Yes        | Target Microsoft 365 tenant (e.g. `contoso.onmicrosoft.com`) |
| `-CsvPath`   | Yes        | Path to CSV file (see format above)                          |
| `-Endpoint`  |          | Existing or new migration endpoint name                      |
| `-BatchName` |          | Exchange migration-batch name                                |
| `-LogFolder` |          | Directory for log files (defaults to `.\logs`)               |
---

## Troubleshooting
| Symptom                   | Fix                                                       |
| ------------------------- | --------------------------------------------------------- |
| Batch stuck **Syncing**   | Verify SourceEndpoint credentials and on-prem throttling. |
| SPMT job **AccessDenied** | Ensure user is licensed and OneDrive URL is correct.      |
| “Module not found” errors | `Install-Module <name> -Scope CurrentUser -Force`         |
---

## CSV Format

```csv
UPN,OneDriveURL
jane.doe@contoso.com,https://contoso-my.sharepoint.com/personal/jane_doe_contoso_com/Documents
john.smith@contoso.com,https://contoso-my.sharepoint.com/personal/john_smith_contoso_com/Documents
