# Marketplace Linux VMs with SSH Keys

This Terraform configuration creates 2 Linux VMs using marketplace images with SSH key authentication and for_each loops.

## Architecture

- **2 Linux VMs**: web-server and api-server
- **Single VNet**: 10.0.0.0/16 with separate subnets per VM
- **SSH Keys**: Generated per VM using `for_each` and stored in Key Vault
- **Marketplace Image**: Ubuntu 22.04 LTS by default
- **Network Security**: SSH (port 22) and HTTP (port 80) access allowed
- **Public IPs**: Each VM gets its own static public IP

## Resources Created

- Resource Group
- Virtual Network with 2 subnets
- Network Security Group
- 2 Linux VMs (azurerm_linux_virtual_machine)
- 2 SSH key pairs (stored in Key Vault)
- 2 Public IPs
- 2 Network Interfaces
- Key Vault for secrets storage

## Usage

1. **Initialize Terraform**:
   ```bash
   cd marketplace-vms
   terraform init
   ```

2. **Configure variables** (optional):
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Plan the deployment**:
   ```bash
   terraform plan
   ```

4. **Apply the configuration**:
   ```bash
   terraform apply
   ```

5. **Connect to VMs**:
   ```bash
   # Get the private keys from Key Vault first
   # Then use the SSH commands from output
   ssh -i <path_to_private_key> azureuser@<vm_public_ip>
   ```

## Key Features

### For Each Implementation
The configuration uses `for_each` with this local variable:
```hcl
locals {
  vm_instances = {
    "web" = { name = "web-server", subnet_cidr = "10.0.1.0/24" }
    "api" = { name = "api-server", subnet_cidr = "10.0.2.0/24" }
  }
}
```

### SSH Key Generation
Each VM gets its own SSH key pair:
```hcl
resource "tls_private_key" "linux_ssh_key" {
  for_each  = local.vm_instances
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

### VM Configuration
Uses `azurerm_linux_virtual_machine` with marketplace image:
```hcl
source_image_reference {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-gen2"
  version   = "latest"
}
```

## Outputs

After deployment, you'll get:
- VM IDs and names
- Public and private IP addresses
- SSH connection commands
- Key Vault secret names for SSH keys

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Customization

You can easily modify the `vm_instances` local variable to:
- Add more VMs
- Change VM names
- Adjust subnet CIDR ranges
- Modify VM configurations per instance