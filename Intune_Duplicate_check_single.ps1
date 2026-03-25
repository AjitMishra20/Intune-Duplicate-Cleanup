<#
DRY RUN (Single device) – Intune duplicate check by Serial Number
- Looks up Intune managedDevices for ONE Serial Number
- Selects the record to KEEP (most recent lastSyncDateTime)
- Lists record(s) that would be deleted (but DOES NOT delete)

No deletion is performed because we do NOT call:
- DELETE /deviceManagement/managedDevices/{managedDeviceId} [1](https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-delete?view=graph-rest-1.0)
- Remove-MgDeviceManagementManagedDevice [2](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.devicemanagement/remove-mgdevicemanagementmanageddevice?view=graph-powershell-1.0)
#>

# ----------------------------
# INPUT (edit this)
# ----------------------------
$SerialNumber = "K2N2F3XN9J"   # e.g. "C02XXXXXXX"

# Output folder
$ExportFolder = ".\IntuneDeviceDryRun"
$RunId = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Path $ExportFolder -Force | Out-Null

# ----------------------------
# CONNECT
# ----------------------------
# Read permission is enough for dry run. If you already use the full cleanup scope, it also works.
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" | Out-Null

Write-Host "=== DRY RUN: Intune Duplicate Check (Serial: $SerialNumber) ===" -ForegroundColor Cyan

# ----------------------------
# FETCH matching Intune records
# ----------------------------
$matches = Get-MgDeviceManagementManagedDevice -All -Property `
"id,deviceName,serialNumber,azureADDeviceId,lastSyncDateTime,operatingSystem,osVersion,model,userPrincipalName,enrolledDateTime" |
Where-Object { $_.serialNumber -and $_.serialNumber.Trim().ToUpper() -eq $SerialNumber.Trim().ToUpper() } |
Select-Object id, deviceName, serialNumber, azureADDeviceId, lastSyncDateTime, operatingSystem, osVersion, model, userPrincipalName, enrolledDateTime

if (-not $matches -or $matches.Count -eq 0) {
  Write-Host "No Intune managed device records found for serial: $SerialNumber" -ForegroundColor Yellow
  return
}

Write-Host "Records found for serial [$SerialNumber]: $($matches.Count)" -ForegroundColor Green
$matches | Sort-Object lastSyncDateTime -Descending | Format-Table -AutoSize

# ----------------------------
# Decide KEEP vs WOULD-DELETE
# ----------------------------
# Keep the most recent lastSyncDateTime; treat null as very old.
$sorted = $matches | Sort-Object @{ Expression = { if ($_.lastSyncDateTime) { $_.lastSyncDateTime } else { [datetime]'1900-01-01' } }; Descending = $true }
$keep   = $sorted[0]
$remove = $sorted | Select-Object -Skip 1

Write-Host "`nKEEP (latest lastSyncDateTime):" -ForegroundColor Cyan
$keep | Format-List

if ($remove.Count -eq 0) {
  Write-Host "No duplicates detected for this serial number. Nothing would be deleted." -ForegroundColor Green
} else {
  Write-Host "`nWOULD DELETE (duplicates – DRY RUN only, no deletion performed):" -ForegroundColor Magenta
  $remove | Format-Table id, deviceName, lastSyncDateTime, operatingSystem, userPrincipalName -AutoSize
}

# ----------------------------
# Export report
# ----------------------------
$report = foreach ($d in $sorted) {
  [pscustomobject]@{
    SerialNumber     = $SerialNumber
    Action           = if ($d.id -eq $keep.id) { "KEEP" } else { "WOULD_DELETE (DRY RUN)" }
    ManagedDeviceId  = $d.id
    DeviceName       = $d.deviceName
    LastSyncDateTime = $d.lastSyncDateTime
    OS               = $d.operatingSystem
    UPN              = $d.userPrincipalName
    AzureADDeviceId  = $d.azureADDeviceId
  }
}

$csvPath = Join-Path $ExportFolder "DryRun_Serial_$($SerialNumber)_$RunId.csv"
$report | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "`nDry-run report exported to: $csvPath" -ForegroundColor Green
Write-Host "=== END DRY RUN ===" -ForegroundColor Cyan