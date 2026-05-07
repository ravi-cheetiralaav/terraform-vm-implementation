# Install Demo - Windows VM with Custom Script Extension

This project demonstrates deploying a Windows Server VM from Azure Marketplace with a VM extension that executes a custom PowerShell script. The script receives parameters from Terraform variables including server name and resource tags.

## Architecture

- **Windows Server VM**: Deployed from Azure Marketplace (Windows Server 2022 Datacenter)
- **VM Extension**: Custom Script Extension with direct script content delivery
- **Parameters**: Script receives `server` and `tags` variables via template substitution
- **Networking**: VNet with public IP for RDP access
- **Storage**: Storage account for boot diagnostics only

## Features

- ✅ Marketplace Windows VM deployment
- ✅ Custom Script Extension with direct script content delivery (no blob storage)
- ✅ Template-based parameter substitution from Terraform
- ✅ Script logging and error handling
- ✅ Network connectivity testing
- ✅ System information gathering
- ✅ Automated directory and file creation
- ✅ Comprehensive output information

## Prerequisites

- Azure CLI or PowerShell Azure module
- Terraform >= 1.0
- Valid Azure subscription
- Appropriate permissions to create resources

## Quick Start

1. **Clone and Navigate**
   ```bash
   cd install-demo
   ```

2. **Configure Variables**
   ```bash
   # Copy example file
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit terraform.tfvars with your values
   # Required: server, admin_password
   ```

3. **Initialize and Deploy**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Connect to VM**
   ```bash
   # Use RDP connection string from output
   mstsc /v:<public_ip_address>
   ```

## Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `server` | Server name identifier | `"web-server-01"` |
| `admin_password` | VM admin password | `"P@ssw0rd123!"` |

## Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `tags` | `{Environment="Demo", Project="InstallDemo"}` | Resource tags |
| `location` | `"Australia East"` | Azure region |
| `vm_size` | `"Standard_B2s"` | VM size |
| `resource_group_name` | `"rg-install-demo"` | Resource group name |

## Script Parameters

The PowerShell script (`scripts/setup.ps1`) receives parameters via Terraform template substitution:

- **Server**: The server name from Terraform variable
- **Tags**: JSON string of all resource tags

*Note: Script content is passed directly to VM extension using base64 encoding - no external storage required.*

## What the Script Does

1. **Template Processing**: Receives server name and tags via Terraform template substitution
2. **System Information**: Displays OS, PowerShell version, computer name
3. **Directory Creation**: Creates `C:\SetupDemo` directory
4. **Information File**: Writes server details to `server-info.txt`
5. **Network Test**: Tests connectivity to external DNS (8.8.8.8)
6. **Logging**: All actions logged to `C:\Windows\Temp\setup-install.log`

## File Structure

```
install-demo/
├── scripts/
│   └── setup.ps1              # PowerShell script executed by VM extension
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── versions.tf                # Terraform and provider versions
├── terraform.tfvars.example   # Example variable values
└── README.md                  # This file
```

## Outputs

After deployment, you'll get:

- VM name and IDs
- Public and private IP addresses
- RDP connection command
- Extension status
- Script delivery method
- Script parameters used

## Viewing Installation Logs

### 🔍 **Azure Portal**
- Navigate to your VM in the Azure Portal
- Go to **Extensions + applications** blade
- Click on **SetupExtension** to see status and basic output

### 💻 **On the VM (via RDP)**
Connect using the RDP connection command from Terraform output.

**Extension Logs Location:**
```
C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.10\
```

**Extension Files Location:**
```
C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10\Downloads\0\
```

**Windows Event Logs:**
- Open **Event Viewer** → **Windows Logs** → **Application**
- Look for events from **WindowsAzureGuestAgent**

### 🖥️ **Azure CLI Commands**
```bash
# Check extension status
az vm extension show --resource-group <rg-name> --vm-name <vm-name> --name SetupExtension

# List all extensions
az vm extension list --resource-group <rg-name> --vm-name <vm-name>
```

### 📋 **Script Output (Echo Statements)**
Your PowerShell script echo statements are captured in specific log files on the VM:

**Primary Location (RDP to VM):**
```
C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.10\CommandExecution.log
```

**Alternative Locations:**
```
C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.21\Downloads\0\stdout
C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.21\Downloads\0\stderr
```

**Expected Output:**
```
Server Parameter: web-server-01
Tags Parameter: {"Application":"VM Extension Demo","CostCenter":"IT-Demo",...}
Script executed successfully as admin user
```

**RDP Connection Details:**
- Use IP from Terraform output: `mstsc /v:<public_ip>:3389`
- Username: `azureuser`
- Password: `Password123#`

## Troubleshooting

### VM Extension Issues

1. **Check Extension Status**
   ```bash
   # Azure CLI
   az vm extension show --resource-group <rg-name> --vm-name <vm-name> --name SetupExtension
   ```

2. **View Extension Logs**
   Connect via RDP and check:
   - `C:\Windows\Temp\setup-install.log` (script log)
   - `C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\` (extension logs)

3. **Manual Script Testing**
   The script is delivered directly to the VM extension. To test manually:
   ```powershell
   # Create a test version on the VM
   # Copy your script content to C:\Windows\Temp\test-setup.ps1
   .\test-setup.ps1
   ```

### Common Issues

- **Extension Timeout**: Increase timeout in `main.tf` if script takes longer
- **Script Errors**: Check PowerShell execution policy and script syntax
- **Network Issues**: Verify NSG rules allow RDP (port 3389)
- **Authentication**: Ensure password meets Azure complexity requirements

## Security Considerations

- Password is marked as sensitive in Terraform
- VM uses managed identity for Azure resource access
- NSG restricts access to RDP port only
- Script content is base64-encoded and passed securely via protected settings
- No external storage dependencies for script delivery

## Benefits of Direct Script Delivery

- **No Storage Dependencies**: Script delivered directly without requiring blob storage
- **Simplified Architecture**: Fewer resources to manage and secure
- **Cost Efficient**: No additional storage costs for script hosting
- **Secure**: Script content transmitted via encrypted protected settings
- **Reliable**: No dependency on external URLs or storage availability

## Customization

### Adding More Script Parameters

1. Add variable to `variables.tf`
2. Update template substitution in `main.tf` extension configuration
3. Modify `setup.ps1` to use new template variable (e.g., `${NewParam}`)

### Installing Software

Replace echo commands in `setup.ps1` with actual software installation:

```powershell
# Example: Install IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
```

## Cleanup

```bash
terraform destroy
```

## Tags and Metadata

The deployment automatically applies tags to all resources and passes them to the PowerShell script via template substitution for use in configuration or monitoring. The script receives variables through Terraform's `templatefile()` function, ensuring secure and reliable parameter delivery.

## Support

For issues specific to this implementation, check:
1. Extension logs on the VM
2. Azure Portal VM extension status
3. Terraform state and plan output