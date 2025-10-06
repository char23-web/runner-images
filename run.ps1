#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Runner Images build and deployment helper script

.DESCRIPTION
    This script provides a simple CLI interface to build runner images and deploy VMs.

.PARAMETER Command
    The command to execute: build, deploy, or help

.PARAMETER ImageType
    (Build) Image type: ubuntu2204, ubuntu2404, windows2019, windows2022, windows2025

.PARAMETER SubscriptionId
    Azure subscription ID

.PARAMETER ResourceGroupName
    Azure resource group name

.PARAMETER AzureLocation
    Azure location (e.g., eastus, westus2)

.PARAMETER ClientId
    (Optional) Service principal client ID

.PARAMETER ClientSecret
    (Optional) Service principal client secret

.PARAMETER TenantId
    (Optional) Azure tenant ID

.PARAMETER ImageName
    (Deploy) Name of the managed image to deploy from

.PARAMETER VirtualMachineName
    (Deploy) Name for the new virtual machine

.PARAMETER AdminUsername
    (Deploy) Administrator username for the VM

.PARAMETER AdminPassword
    (Deploy) Administrator password for the VM

.EXAMPLE
    .\run.ps1 build -ImageType ubuntu2404 -SubscriptionId "xxx" -ResourceGroupName "myRG" -AzureLocation "eastus"

.EXAMPLE
    .\run.ps1 deploy -ImageName "myImage" -VirtualMachineName "myVM" -SubscriptionId "xxx" -ResourceGroupName "myRG" -AzureLocation "eastus" -AdminUsername "admin" -AdminPassword "SecurePass123!"

.EXAMPLE
    .\run.ps1 help
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('build', 'deploy', 'help')]
    [string]$Command,

    # Build parameters
    [Parameter(Mandatory = $false)]
    [ValidateSet('ubuntu2204', 'ubuntu2404', 'windows2019', 'windows2022', 'windows2025')]
    [string]$ImageType,

    # Common parameters
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$AzureLocation,

    [Parameter(Mandatory = $false)]
    [string]$ClientId,

    [Parameter(Mandatory = $false)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false)]
    [string]$TenantId,

    # Deploy parameters
    [Parameter(Mandatory = $false)]
    [string]$ImageName,

    [Parameter(Mandatory = $false)]
    [string]$VirtualMachineName,

    [Parameter(Mandatory = $false)]
    [string]$AdminUsername,

    [Parameter(Mandatory = $false)]
    [string]$AdminPassword
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-ColorOutput "Error: $Message" -Color Red
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-ColorOutput $Message -Color Green
}

function Write-InfoMessage {
    param([string]$Message)
    Write-ColorOutput $Message -Color Yellow
}

function Show-Help {
    $helpText = @"

Runner Images Build and Deploy Helper

Usage: .\run.ps1 <command> [options]

Commands:
    build       Build a runner image using Packer
    deploy      Deploy a VM from a built image
    help        Show this help message

Build Options:
    -ImageType <type>           Image type: ubuntu2204, ubuntu2404, windows2019, windows2022, windows2025 (required)
    -SubscriptionId <id>        Azure subscription ID (required)
    -ResourceGroupName <name>   Resource group name (required)
    -AzureLocation <location>   Azure location, e.g., eastus (required)
    -ClientId <id>             Service principal client ID (optional)
    -ClientSecret <secret>      Service principal client secret (optional)
    -TenantId <id>             Azure tenant ID (optional)

Deploy Options:
    -ImageName <name>           Name of the managed image (required)
    -VirtualMachineName <name>  Name for the new VM (required)
    -SubscriptionId <id>        Azure subscription ID (required)
    -ResourceGroupName <name>   Resource group name (required)
    -AzureLocation <location>   Azure location (required)
    -AdminUsername <user>       VM admin username (required)
    -AdminPassword <pass>       VM admin password (required)

Examples:
    # Build Ubuntu 24.04 image
    .\run.ps1 build -ImageType ubuntu2404 -SubscriptionId "xxx" -ResourceGroupName myRG -AzureLocation eastus

    # Deploy VM from image
    .\run.ps1 deploy -ImageName myImage -VirtualMachineName myVM -SubscriptionId "xxx" -ResourceGroupName myRG -AzureLocation eastus -AdminUsername admin -AdminPassword 'SecurePass123!'

"@
    Write-Host $helpText
}

function Test-Prerequisites {
    $missingTools = @()
    
    # Check for Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        $missingTools += "az (Azure CLI)"
    }
    
    # Check for Packer
    if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
        $missingTools += "packer"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-ErrorMessage "Missing required tools: $($missingTools -join ', ')"
        Write-Host ""
        Write-Host "Please install the following:"
        foreach ($tool in $missingTools) {
            switch -Wildcard ($tool) {
                "*Azure CLI*" {
                    Write-Host "  - Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
                }
                "*packer*" {
                    Write-Host "  - Packer: https://www.packer.io/downloads"
                }
            }
        }
        exit 1
    }
}

function Invoke-BuildImage {
    # Validate required parameters
    if ([string]::IsNullOrEmpty($ImageType)) {
        Write-ErrorMessage "ImageType is required for build command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($SubscriptionId)) {
        Write-ErrorMessage "SubscriptionId is required for build command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($ResourceGroupName)) {
        Write-ErrorMessage "ResourceGroupName is required for build command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($AzureLocation)) {
        Write-ErrorMessage "AzureLocation is required for build command"
        Show-Help
        exit 1
    }
    
    Write-InfoMessage "Building $ImageType image..."
    Write-InfoMessage "Subscription: $SubscriptionId"
    Write-InfoMessage "Resource Group: $ResourceGroupName"
    Write-InfoMessage "Location: $AzureLocation"
    Write-Host ""
    
    try {
        # Import the helper module
        $helperScript = Join-Path $ScriptDir "helpers" "GenerateResourcesAndImage.ps1"
        Import-Module $helperScript -Force
        
        # Build parameters
        $buildParams = @{
            SubscriptionId     = $SubscriptionId
            ResourceGroupName  = $ResourceGroupName
            ImageType          = $ImageType
            AzureLocation      = $AzureLocation
        }
        
        # Add optional parameters if provided
        if (-not [string]::IsNullOrEmpty($ClientId)) {
            $buildParams.AzureClientId = $ClientId
        }
        
        if (-not [string]::IsNullOrEmpty($ClientSecret)) {
            $buildParams.AzureClientSecret = $ClientSecret
        }
        
        if (-not [string]::IsNullOrEmpty($TenantId)) {
            $buildParams.AzureTenantId = $TenantId
        }
        
        # Call the function
        GenerateResourcesAndImage @buildParams
        
        Write-Host ""
        Write-SuccessMessage "Image build completed successfully!"
    }
    catch {
        Write-ErrorMessage "Image build failed: $_"
        exit 1
    }
}

function Invoke-DeployVM {
    # Validate required parameters
    if ([string]::IsNullOrEmpty($ImageName)) {
        Write-ErrorMessage "ImageName is required for deploy command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($VirtualMachineName)) {
        Write-ErrorMessage "VirtualMachineName is required for deploy command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($SubscriptionId)) {
        Write-ErrorMessage "SubscriptionId is required for deploy command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($ResourceGroupName)) {
        Write-ErrorMessage "ResourceGroupName is required for deploy command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($AzureLocation)) {
        Write-ErrorMessage "AzureLocation is required for deploy command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($AdminUsername)) {
        Write-ErrorMessage "AdminUsername is required for deploy command"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($AdminPassword)) {
        Write-ErrorMessage "AdminPassword is required for deploy command"
        Show-Help
        exit 1
    }
    
    Write-InfoMessage "Deploying VM from image..."
    Write-InfoMessage "Image: $ImageName"
    Write-InfoMessage "VM Name: $VirtualMachineName"
    Write-InfoMessage "Subscription: $SubscriptionId"
    Write-InfoMessage "Resource Group: $ResourceGroupName"
    Write-InfoMessage "Location: $AzureLocation"
    Write-Host ""
    
    try {
        # Import the helper module
        $helperScript = Join-Path $ScriptDir "helpers" "CreateAzureVMFromPackerTemplate.ps1"
        Import-Module $helperScript -Force
        
        # Call the function
        CreateAzureVMFromPackerTemplate `
            -SubscriptionId $SubscriptionId `
            -ResourceGroupName $ResourceGroupName `
            -ManagedImageName $ImageName `
            -VirtualMachineName $VirtualMachineName `
            -AdminUsername $AdminUsername `
            -AdminPassword $AdminPassword `
            -AzureLocation $AzureLocation
        
        Write-Host ""
        Write-SuccessMessage "VM deployment completed successfully!"
    }
    catch {
        Write-ErrorMessage "VM deployment failed: $_"
        exit 1
    }
}

# Main script logic
switch ($Command) {
    'build' {
        Test-Prerequisites
        Invoke-BuildImage
    }
    'deploy' {
        Test-Prerequisites
        Invoke-DeployVM
    }
    'help' {
        Show-Help
    }
    default {
        Write-ErrorMessage "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
