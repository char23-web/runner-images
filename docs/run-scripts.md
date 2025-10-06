# Run Scripts Documentation

This repository includes convenient wrapper scripts (`run.sh` and `run.ps1`) that simplify the process of building runner images and deploying VMs from those images.

## Prerequisites

Before using these scripts, ensure you have the following installed:

1. **PowerShell** (version 5.0 or higher)
   - Linux/macOS: [Installation guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
   - Windows: Already included

2. **Azure CLI**
   - [Installation guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

3. **Packer** (version 1.8.2 or higher)
   - [Download from here](https://www.packer.io/downloads)

4. **Git**
   - [Installation guide](https://git-scm.com/downloads)

## Usage

### Linux/macOS (Bash Script)

#### Build an Image

```bash
./run.sh build \
  --image-type ubuntu2404 \
  --subscription-id <your-subscription-id> \
  --resource-group myResourceGroup \
  --location eastus
```

#### Deploy a VM

```bash
./run.sh deploy \
  --image-name myGeneratedImage \
  --vm-name myTestVM \
  --subscription-id <your-subscription-id> \
  --resource-group myResourceGroup \
  --location eastus \
  --admin-username azureuser \
  --admin-password 'YourSecurePassword123!'
```

#### Get Help

```bash
./run.sh help
```

### Windows/PowerShell

#### Build an Image

```powershell
.\run.ps1 build `
  -ImageType ubuntu2404 `
  -SubscriptionId <your-subscription-id> `
  -ResourceGroupName myResourceGroup `
  -AzureLocation eastus
```

#### Deploy a VM

```powershell
.\run.ps1 deploy `
  -ImageName myGeneratedImage `
  -VirtualMachineName myTestVM `
  -SubscriptionId <your-subscription-id> `
  -ResourceGroupName myResourceGroup `
  -AzureLocation eastus `
  -AdminUsername azureuser `
  -AdminPassword 'YourSecurePassword123!'
```

#### Get Help

```powershell
.\run.ps1 help
```

## Available Image Types

The following image types are supported:

- `ubuntu2204` - Ubuntu 22.04 LTS
- `ubuntu2404` - Ubuntu 24.04 LTS
- `windows2019` - Windows Server 2019
- `windows2022` - Windows Server 2022
- `windows2025` - Windows Server 2025

## Build Options

### Required Parameters

- `--image-type` / `-ImageType`: The type of image to build (see available types above)
- `--subscription-id` / `-SubscriptionId`: Your Azure subscription ID
- `--resource-group` / `-ResourceGroupName`: The resource group where the image will be stored
- `--location` / `-AzureLocation`: Azure region (e.g., eastus, westus2, northeurope)

### Optional Parameters

- `--client-id` / `-ClientId`: Service principal client ID (for non-interactive authentication)
- `--client-secret` / `-ClientSecret`: Service principal client secret
- `--tenant-id` / `-TenantId`: Azure tenant ID

## Deploy Options

### Required Parameters

- `--image-name` / `-ImageName`: Name of the managed image to deploy from
- `--vm-name` / `-VirtualMachineName`: Name for the new virtual machine
- `--subscription-id` / `-SubscriptionId`: Your Azure subscription ID
- `--resource-group` / `-ResourceGroupName`: Resource group for the VM
- `--location` / `-AzureLocation`: Azure region
- `--admin-username` / `-AdminUsername`: Administrator username
- `--admin-password` / `-AdminPassword`: Administrator password

## Examples

### Example 1: Build Ubuntu 24.04 Image

**Bash:**
```bash
./run.sh build \
  --image-type ubuntu2404 \
  --subscription-id "12345678-1234-1234-1234-123456789012" \
  --resource-group "runner-images-rg" \
  --location eastus
```

**PowerShell:**
```powershell
.\run.ps1 build `
  -ImageType ubuntu2404 `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -ResourceGroupName "runner-images-rg" `
  -AzureLocation eastus
```

### Example 2: Build Windows Server 2022 Image with Service Principal

**Bash:**
```bash
./run.sh build \
  --image-type windows2022 \
  --subscription-id "12345678-1234-1234-1234-123456789012" \
  --resource-group "runner-images-rg" \
  --location eastus \
  --client-id "sp-client-id" \
  --client-secret "sp-client-secret" \
  --tenant-id "tenant-id"
```

**PowerShell:**
```powershell
.\run.ps1 build `
  -ImageType windows2022 `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -ResourceGroupName "runner-images-rg" `
  -AzureLocation eastus `
  -ClientId "sp-client-id" `
  -ClientSecret "sp-client-secret" `
  -TenantId "tenant-id"
```

### Example 3: Deploy a VM from Built Image

**Bash:**
```bash
./run.sh deploy \
  --image-name "Runner-Image-Ubuntu2404" \
  --vm-name "test-runner-vm" \
  --subscription-id "12345678-1234-1234-1234-123456789012" \
  --resource-group "runner-images-rg" \
  --location eastus \
  --admin-username "azureuser" \
  --admin-password "MySecurePassword123!"
```

**PowerShell:**
```powershell
.\run.ps1 deploy `
  -ImageName "Runner-Image-Ubuntu2404" `
  -VirtualMachineName "test-runner-vm" `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -ResourceGroupName "runner-images-rg" `
  -AzureLocation eastus `
  -AdminUsername "azureuser" `
  -AdminPassword "MySecurePassword123!"
```

## Authentication

The scripts support two authentication methods:

1. **Interactive Authentication** (default): The scripts will prompt you to log in via Azure CLI if not already authenticated.

2. **Service Principal Authentication**: Provide `--client-id`, `--client-secret`, and `--tenant-id` parameters to authenticate non-interactively.

To authenticate with Azure CLI manually before running the scripts:

```bash
az login
az account set --subscription <your-subscription-id>
```

## Troubleshooting

### Common Issues

1. **Missing Prerequisites**: Ensure all required tools (PowerShell, Azure CLI, Packer, Git) are installed and in your PATH.

2. **Authentication Errors**: Make sure you're logged in to Azure CLI or have provided valid service principal credentials.

3. **Resource Group Not Found**: Ensure the specified resource group exists in your subscription before running the build command.

4. **Permission Issues**: Verify your Azure account has appropriate permissions to create resources in the specified subscription and resource group.

### Getting More Information

For detailed information about the image generation process, see the [full documentation](create-image-and-azure-resources.md).

## Advanced Usage

For more advanced scenarios or to customize the build process, you can use the underlying PowerShell modules directly:

- `helpers/GenerateResourcesAndImage.ps1` - For building images
- `helpers/CreateAzureVMFromPackerTemplate.ps1` - For deploying VMs

Run `Get-Help <function-name> -Detailed` for more information on each function.
