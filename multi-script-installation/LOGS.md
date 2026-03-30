# VM Extension Log Locations

Use this reference on the Windows VM to troubleshoot `CustomScriptExtension`.

## Azure extension logs

1. `C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.*\`
2. `C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.*\Status\`
3. `C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.*\Downloads\0\` (downloaded scripts)

## Script logs created by this deployment

1. `C:\Logs\script1.log`
2. `C:\Logs\script2.log`
3. `C:\Logs\script3.log`

## Quick PowerShell commands

```powershell
Get-ChildItem "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension" -Recurse
Get-Content "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.*\*.log" -Tail 200
Get-ChildItem "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.*\Status"
Get-Content "C:\Logs\script1.log","C:\Logs\script2.log","C:\Logs\script3.log" -ErrorAction SilentlyContinue
```
