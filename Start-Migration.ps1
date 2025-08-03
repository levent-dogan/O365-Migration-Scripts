<#
    Start-Migration.ps1 – Staged Exchange + OneDrive migration orchestrator
    Author : Levent D. (⏱ 2025‑08 Rev‑2)
    Description: Automates creation of Exchange Online staged migration batches
                 and kicks off SPMT‑based OneDrive moves for users in a CSV.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Tenant,
    [Parameter(Mandatory)][string]$CsvPath,
    [string]$Endpoint   = "OnPrem-EndPoint",
    [string]$BatchName  = "Stage-001",
    [string]$LogFolder  = ".\\logs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helper functions ──────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message,[ValidateSet('INFO','WARN','ERROR','FATAL')][string]$Level = 'INFO')
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Host "[$ts][$Level] $Message"
    "$ts,$Level,$Message" | Out-File -FilePath $Script:LogFile -Append -Encoding utf8
}

function Test-ModuleInstalled([string[]]$Names){
    foreach ($n in $Names){
        if (-not (Get-Module -ListAvailable -Name $n)){
            throw "Required module '$n' is not installed."
        }
    }
}

function Ensure-ExchangeConnection{
    if (-not (Get-ConnectionInformation | Where-Object Name -eq 'ExchangeOnline')){
        Write-Log "Connecting to Exchange Online…"
        Connect-ExchangeOnline -Organization $Tenant -Device
    }
}

function Ensure-SPOConnection{
    if (-not (Get-PnPContext)){
        $adminUrl = "https://$($Tenant.Split('.')[0])-admin.sharepoint.com"
        Write-Log "Connecting to SPO admin $adminUrl…"
        Connect-SPOService -Url $adminUrl
    }
}

function Ensure-MigrationEndpoint{
    if (-not (Get-MigrationEndpoint -Identity $Endpoint -ErrorAction SilentlyContinue)){
        Write-Log "Creating migration endpoint '$Endpoint'…"
        New-MigrationEndpoint -RemoteServer '<onprem.EWS.FQDN>' -Name $Endpoint `
            -ExchangeRemoteMove -Credentials (Get-Credential)
    }
}

function Start-OneDriveMigration($User){
    $src = "\\\\FILESERVER\\Home\\$($User.UPN)"
    if (-not (Test-Path $src)){
        throw "Source path $src not found."
    }
    $tgt = $User.OneDriveURL
    $jobRoot = Join-Path -Path $env:TEMP -ChildPath "SPMT_$($User.UPN)"
    $cfgPath = Join-Path $jobRoot 'config.json'

    $json = @{Tasks = @(@{
                SourcePath            = $src
                TargetPath            = $tgt
                TargetDocumentLibrary = 'Documents'
                Credentials           = $null
           }) } | ConvertTo-Json -Depth 4

    New-Item $jobRoot -ItemType Directory -Force | Out-Null
    $json | Set-Content -Path $cfgPath -Encoding utf8

    Write-Log "Registering SPMT job for $($User.UPN)…"
    Register-SPMTMigration -ConfigFilePath $cfgPath
}
# ─────────────────────────────────────────────────────────────────────────────

# Initialise log
New-Item $LogFolder -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogFolder ("Migration-$(Get-Date -Format yyyyMMdd-HHmmss).log")

try{
    Write-Log "Validating prerequisites…"
    Test-ModuleInstalled @('ExchangeOnlineManagement','SharePointPnPPowerShellOnline','Microsoft.SharePoint.MigrationTool.PowerShell')

    Write-Log "Importing CSV $CsvPath…"
    $Users = Import-Csv -Path $CsvPath
    if(-not $Users){ throw 'CSV contains no rows.' }

    Ensure-ExchangeConnection
    Ensure-MigrationEndpoint

    if(Get-MigrationBatch -Identity $BatchName -ErrorAction SilentlyContinue){
        Write-Log "Batch $BatchName already exists, skipping create."
    }else{
        Write-Log "Creating migration batch $BatchName…"
        $UserIds = $Users | Select-Object -ExpandProperty UPN
        New-MigrationBatch -Name $BatchName -UserIds $UserIds `
            -SourceEndpoint $Endpoint -AutoStart -AutoComplete
    }

    Write-Log "Starting OneDrive migrations…"
    Ensure-SPOConnection
    $Users | ForEach-Object {
        try{ Start-OneDriveMigration $_ }
        catch{ Write-Log $_.Exception.Message 'ERROR' }
    }

    Write-Log "All commands submitted. Track progress with Get-MigrationUser & Get-SPMTMigrationTask."
}
catch{
    Write-Log $_.Exception.Message 'FATAL'
    throw
}
finally{
    Write-Log 'Done.'
}
