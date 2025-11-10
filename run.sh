#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_usage() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
    build       Build a runner image using Packer
    deploy      Deploy a VM from a built image
    help        Show this help message

Build options:
    --image-type <type>         Image type: ubuntu2204, ubuntu2404, windows2019, windows2022, windows2025 (required)
    --subscription-id <id>      Azure subscription ID (required)
    --resource-group <name>     Resource group name (required)
    --location <location>       Azure location, e.g., eastus (required)
    --client-id <id>           Service principal client ID
    --client-secret <secret>    Service principal client secret
    --tenant-id <id>           Azure tenant ID

Deploy options:
    --image-name <name>         Name of the managed image (required)
    --vm-name <name>           Name for the new VM (required)
    --subscription-id <id>      Azure subscription ID (required)
    --resource-group <name>     Resource group name (required)
    --location <location>       Azure location (required)
    --admin-username <user>     VM admin username (required)
    --admin-password <pass>     VM admin password (required)

Examples:
    # Build Ubuntu 24.04 image
    $(basename "$0") build --image-type ubuntu2404 --subscription-id <id> --resource-group myRG --location eastus

    # Deploy VM from image
    $(basename "$0") deploy --image-name myImage --vm-name myVM --subscription-id <id> --resource-group myRG --location eastus --admin-username admin --admin-password 'SecurePass123!'

EOF
}

print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${YELLOW}$1${NC}"
}

check_prerequisites() {
    local missing_tools=()
    
    if ! command -v pwsh &> /dev/null; then
        missing_tools+=("pwsh")
    fi
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("az")
    fi
    
    if ! command -v packer &> /dev/null; then
        missing_tools+=("packer")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the following:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                pwsh)
                    echo "  - PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell"
                    ;;
                az)
                    echo "  - Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
                    ;;
                packer)
                    echo "  - Packer: https://www.packer.io/downloads"
                    ;;
            esac
        done
        exit 1
    fi
}

build_image() {
    local image_type=""
    local subscription_id=""
    local resource_group=""
    local location=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image-type)
                image_type="$2"
                shift 2
                ;;
            --subscription-id)
                subscription_id="$2"
                shift 2
                ;;
            --resource-group)
                resource_group="$2"
                shift 2
                ;;
            --location)
                location="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$image_type" ] || [ -z "$subscription_id" ] || [ -z "$resource_group" ] || [ -z "$location" ]; then
        print_error "Missing required arguments for build command"
        print_usage
        exit 1
    fi
    
    # Validate image type
    case $image_type in
        ubuntu2204|ubuntu2404|windows2019|windows2022|windows2025)
            ;;
        *)
            print_error "Invalid image type: $image_type"
            print_usage
            exit 1
            ;;
    esac
    
    print_info "Building $image_type image..."
    print_info "Subscription: $subscription_id"
    print_info "Resource Group: $resource_group"
    print_info "Location: $location"
    
    # Import and run the PowerShell function
    pwsh -Command "
        Import-Module '$SCRIPT_DIR/helpers/GenerateResourcesAndImage.ps1'
        GenerateResourcesAndImage -SubscriptionId '$subscription_id' -ResourceGroupName '$resource_group' -ImageType '$image_type' -AzureLocation '$location'
    "
    
    if [ $? -eq 0 ]; then
        print_success "Image build completed successfully!"
    else
        print_error "Image build failed"
        exit 1
    fi
}

deploy_vm() {
    local image_name=""
    local vm_name=""
    local subscription_id=""
    local resource_group=""
    local location=""
    local admin_username=""
    local admin_password=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image-name)
                image_name="$2"
                shift 2
                ;;
            --vm-name)
                vm_name="$2"
                shift 2
                ;;
            --subscription-id)
                subscription_id="$2"
                shift 2
                ;;
            --resource-group)
                resource_group="$2"
                shift 2
                ;;
            --location)
                location="$2"
                shift 2
                ;;
            --admin-username)
                admin_username="$2"
                shift 2
                ;;
            --admin-password)
                admin_password="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$image_name" ] || [ -z "$vm_name" ] || [ -z "$subscription_id" ] || \
       [ -z "$resource_group" ] || [ -z "$location" ] || [ -z "$admin_username" ] || \
       [ -z "$admin_password" ]; then
        print_error "Missing required arguments for deploy command"
        print_usage
        exit 1
    fi
    
    print_info "Deploying VM from image..."
    print_info "Image: $image_name"
    print_info "VM Name: $vm_name"
    print_info "Subscription: $subscription_id"
    print_info "Resource Group: $resource_group"
    print_info "Location: $location"
    
    # Import and run the PowerShell function
    pwsh -Command "
        Import-Module '$SCRIPT_DIR/helpers/CreateAzureVMFromPackerTemplate.ps1'
        CreateAzureVMFromPackerTemplate -SubscriptionId '$subscription_id' -ResourceGroupName '$resource_group' -ManagedImageName '$image_name' -VirtualMachineName '$vm_name' -AdminUsername '$admin_username' -AdminPassword '$admin_password' -AzureLocation '$location'
    "
    
    if [ $? -eq 0 ]; then
        print_success "VM deployment completed successfully!"
    else
        print_error "VM deployment failed"
        exit 1
    fi
}

# Main script logic
if [ $# -eq 0 ]; then
    print_usage
    exit 0
fi

COMMAND=$1
shift

case $COMMAND in
    build)
        check_prerequisites
        build_image "$@"
        ;;
    deploy)
        check_prerequisites
        deploy_vm "$@"
        ;;
    help|--help|-h)
        print_usage
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        print_usage
        exit 1
        ;;
esac
