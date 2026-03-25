✅ Project Title
Intune Duplicate Device Cleanup Script (Serial Number Based)

✅ Short Description
Explain what the script does in 2–3 lines:
PowerShell script to detect and safely clean duplicate Intune managed device records using Serial Number. 
It keeps the latest device entry (based on lastSyncDateTime) and deletes only stale duplicates. 
The script deletes Intune managedDevice records only and does NOT touch Entra ID device objects.

✅ Features Section
Example:

✅ Detect duplicate Intune device records
✅ Compare by Serial Number only (highest accuracy)
✅ Keep most recent check-in record
✅ Delete stale duplicates safely
✅ Does not delete Entra ID device objects
✅ Dry-run mode and live mode

✅ Prerequisites
List required modules and permissions:
- PowerShell 7.x  
- Microsoft.Graph PowerShell SDK
- Required Graph Permission:
   DeviceManagementManagedDevices.ReadWrite.All

✅ How to Use (Instructions)
Give steps:

Clone repo
Install Microsoft Graph module
Run script in dry-run mode
Review CSV output
Switch to live-delete script

