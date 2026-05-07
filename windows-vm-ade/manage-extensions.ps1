# Extension Management Script for Failed VM Extensions
# Use this script when extensions fail and Terraform state becomes inconsistent

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("list", "remove-failed", "fix-state", "force-remove")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$VMName,
    
    [Parameter(Mandatory=$false)]
    [string]$ExtensionName
)

function Get-VMExtensions {
    param($ResourceGroup, $VMName)
    
    Write-Host "Fetching VM extensions for $VMName in $ResourceGroup..." -ForegroundColor Yellow
    
    $extensions = az vm extension list --resource-group $ResourceGroup --vm-name $VMName | ConvertFrom-Json
    
    foreach ($ext in $extensions) {
        $status = if ($ext.provisioningState -eq "Failed") { "❌ FAILED" } 
                 elseif ($ext.provisioningState -eq "Succeeded") { "✅ SUCCESS" }
                 else { "⚠️ $($ext.provisioningState)" }
        
        Write-Host "Extension: $($ext.name)" -ForegroundColor Cyan
        Write-Host "  Type: $($ext.typeHandlerVersion)" -ForegroundColor Gray
        Write-Host "  Status: $status" -ForegroundColor $(if ($ext.provisioningState -eq "Failed") { "Red" } else { "Green" })
        Write-Host "  Publisher: $($ext.publisher)" -ForegroundColor Gray
        Write-Host ""
    }
    
    return $extensions
}

function Remove-FailedExtensions {
    param($ResourceGroup, $VMName)
    
    Write-Host "Scanning for failed extensions..." -ForegroundColor Yellow
    
    $extensions = Get-VMExtensions -ResourceGroup $ResourceGroup -VMName $VMName
    $failedExtensions = $extensions | Where-Object { $_.provisioningState -eq "Failed" }
    
    if ($failedExtensions.Count -eq 0) {
        Write-Host "No failed extensions found." -ForegroundColor Green
        return
    }
    
    foreach ($ext in $failedExtensions) {
        Write-Host "Removing failed extension: $($ext.name)" -ForegroundColor Red
        az vm extension delete --resource-group $ResourceGroup --vm-name $VMName --name $ext.name
        Write-Host "✅ Removed extension: $($ext.name)" -ForegroundColor Green
    }
}

function Fix-TerraformState {
    Write-Host "=== Terraform State Repair Instructions ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. List current Terraform state:" -ForegroundColor Yellow
    Write-Host "   terraform state list | grep extension" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Remove the problematic extension from state:" -ForegroundColor Yellow
    Write-Host "   terraform state rm azurerm_virtual_machine_extension.initialize_data_disk" -ForegroundColor Gray
    Write-Host "   terraform state rm azurerm_virtual_machine_extension.ade_windows" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Import the extension if it exists and is working:" -ForegroundColor Yellow
    Write-Host "   terraform import azurerm_virtual_machine_extension.ade_windows /subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm}/extensions/{extension-name}" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Or run terraform plan/apply to recreate:" -ForegroundColor Yellow
    Write-Host "   terraform plan" -ForegroundColor Gray
    Write-Host "   terraform apply" -ForegroundColor Gray
    Write-Host ""
}

function Force-RemoveExtension {
    param($ResourceGroup, $VMName, $ExtensionName)
    
    if (-not $ExtensionName) {
        Write-Host "Extension name is required for force removal." -ForegroundColor Red
        return
    }
    
    Write-Host "Force removing extension: $ExtensionName" -ForegroundColor Red
    
    # Try normal removal first
    try {
        az vm extension delete --resource-group $ResourceGroup --vm-name $VMName --name $ExtensionName
        Write-Host "✅ Extension removed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Normal removal failed, trying alternative methods..." -ForegroundColor Yellow
        
        # Alternative: Use REST API or PowerShell cmdlets
        Write-Host "You may need to use Azure Portal or contact Azure Support for stuck extensions." -ForegroundColor Red
    }
}

# Main execution
switch ($Action) {
    "list" {
        if (-not $ResourceGroupName -or -not $VMName) {
            Write-Host "Resource Group and VM Name are required for listing extensions." -ForegroundColor Red
            exit 1
        }
        Get-VMExtensions -ResourceGroup $ResourceGroupName -VMName $VMName
    }
    
    "remove-failed" {
        if (-not $ResourceGroupName -or -not $VMName) {
            Write-Host "Resource Group and VM Name are required for removing failed extensions." -ForegroundColor Red
            exit 1
        }
        Remove-FailedExtensions -ResourceGroup $ResourceGroupName -VMName $VMName
    }
    
    "fix-state" {
        Fix-TerraformState
    }
    
    "force-remove" {
        if (-not $ResourceGroupName -or -not $VMName -or -not $ExtensionName) {
            Write-Host "Resource Group, VM Name, and Extension Name are required for force removal." -ForegroundColor Red
            exit 1
        }
        Force-RemoveExtension -ResourceGroup $ResourceGroupName -VMName $VMName -ExtensionName $ExtensionName
    }
}

Write-Host ""
Write-Host "=== Extension Management Complete ===" -ForegroundColor Green