#!/bin/bash
# deploy.sh - Deploy all Azure infrastructure

set -e

echo "🚀 Starting Azure Infrastructure Deployment"
echo "============================================="

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Login to Azure
echo "📝 Logging into Azure..."
az login

# Set subscription
if [ -n "$SUBSCRIPTION_ID" ]; then
    echo "🔧 Setting subscription to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

# Deploy main Bicep template
echo "🏗️  Deploying infrastructure..."
DEPLOYMENT_NAME="my-website-deployment-$(date +%Y%m%d-%H%M%S)"
ENVIRONMENT="prod"
LOCATION="centralus"

az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file main.bicep \
  --parameters environment="$ENVIRONMENT" location="$LOCATION" customDomain="$CUSTOM_DOMAIN"

# Get outputs
echo "📊 Getting deployment outputs..."
OUTPUTS=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs)

STATIC_WEB_APP_URL=$(echo "$OUTPUTS" | jq -r '.staticWebAppUrl.value')
STATIC_WEB_APP_NAME=$(echo "$OUTPUTS" | jq -r '.staticWebAppName.value')
MOMENTUM_FINDER_URL=$(echo "$OUTPUTS" | jq -r '.momentumFinderUrl.value')
DIGITS_API_URL=$(echo "$OUTPUTS" | jq -r '.digitsAPIUrl.value')
CONTAINER_REGISTRY=$(echo "$OUTPUTS" | jq -r '.containerRegistryLoginServer.value')
RESOURCE_GROUP=$(echo "$OUTPUTS" | jq -r '.resourceGroupName.value')

echo ""
echo "✅ Deployment completed successfully!"
echo "======================================"
echo ""
echo "📍 Resource Group: $RESOURCE_GROUP"
echo "🌐 Frontend URL: https://$STATIC_WEB_APP_URL"
echo "🔧 Momentum Finder API: $MOMENTUM_FINDER_URL"
echo "🔢 Digits API: $DIGITS_API_URL"
echo "📦 Container Registry: $CONTAINER_REGISTRY"
echo ""
echo "Next steps:"
echo "1. Build and push momentum-finder Docker image"
echo "2. Deploy digits API functions"
echo "3. Configure GitHub Actions for Static Web App"
echo "4. Update DNS records in Route 53"
echo ""
echo "Run './build-and-deploy-apis.sh' to deploy the APIs"