<#
LIVE DELETE (Single device) – Intune duplicate cleanup by Serial Number
- Keeps the most recent lastSyncDateTime record
- Deletes all other Intune managedDevice records for the same serial
- Prompts for confirmation before deletion

Uses:
- Remove-MgDeviceManagementManagedDevice (deletes Intune managedDevice) [2](https://learn.microsoft.com/en-gb/answers/questions/1463604/microsoft-graph-error-assembly-with-same-name-is-a)
Equivalent REST:
- DELETE /deviceManagement/managedDevices/{managedDeviceId} [1](https://bing.com/search?q=Microsoft+Graph+PowerShell+SDK+assembly+with+same+name+already+loaded+error+fix)
#>

# ----------------------------
# INPUT
# ----------------------------
$SerialNumber = "K2N2F3XN9J"   # <-- your serial
$ExportFolder = ".\IntuneDeviceDryRun"
$RunId = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Path $ExportFolder -Force | Out-Null

# ----------------------------
# CONNECT
# ----------------------------
# Needs delete permission for Intune managed devices
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All" | Out-Null

Write-Host "=== LIVE DELETE: Intune Duplicate Cleanup (Serial: $SerialNumber) ===" -ForegroundColor Red

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
# Decide KEEP vs DELETE
# ----------------------------
$sorted = $matches | Sort-Object @{ Expression = { if ($_.lastSyncDateTime) { $_.lastSyncDateTime } else { [datetime]'1900-01-01' } }; Descending = $true }
$keep   = $sorted[0]
$remove = $sorted | Select-Object -Skip 1

Write-Host "`nKEEP (latest lastSyncDateTime):" -ForegroundColor Cyan
$keep | Format-List

if ($remove.Count -eq 0) {
  Write-Host "No duplicates detected for this serial number. Nothing to delete." -ForegroundColor Green
  return
}

Write-Host "`nWILL DELETE the following duplicate Intune record(s):" -ForegroundColor Magenta
$remove | Format-Table id, deviceName, lastSyncDateTime, operatingSystem, userPrincipalName -AutoSize

# Export what you are about to do
$csvPath = Join-Path $ExportFolder "LIVEDELETE_Serial_$($SerialNumber)_$RunId.csv"
$sorted | Select-Object `
  @{n="SerialNumber";e={$SerialNumber}},
  @{n="Action";e={ if ($_.id -eq $keep.id) { "KEEP" } else { "DELETE" } }},
  id, deviceName, lastSyncDateTime, operatingSystem, userPrincipalName, azureADDeviceId |
Export-Csv $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "`nAction report exported to: $csvPath" -ForegroundColor Green

# ----------------------------
# CONFIRMATION PROMPT
# ----------------------------
$confirm = Read-Host "Type YES to delete the above duplicate Intune record(s)"
if ($confirm -ne "YES") {
  Write-Host "Cancelled. No deletions performed." -ForegroundColor Yellow
  return
}

# ----------------------------
# DELETE duplicates (Intune only)
# ----------------------------
foreach ($d in $remove) {
  try {
    Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $d.id
    Write-Host "Deleted Intune duplicate managedDeviceId: $($d.id)" -ForegroundColor Green
  } catch {
    Write-Host "FAILED to delete $($d.id): $($_.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host "=== Completed: Deleted duplicate Intune record(s) for serial $SerialNumber ===" -ForegroundColor Cyan