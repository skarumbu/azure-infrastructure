#!/bin/bash
# build-and-deploy-apis.sh - Build and deploy all APIs

set -e

ENVIRONMENT="prod"
RESOURCE_GROUP="my-website-${ENVIRONMENT}-rg"

echo "🔨 Building and Deploying APIs"
echo "==============================="

# Get resource names from Azure
echo "📋 Getting Azure resource information..."
CONTAINER_REGISTRY=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
CONTAINER_REGISTRY_SERVER=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[0].loginServer" -o tsv)
FUNCTION_APP=$(az functionapp list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
CONTAINER_APP=$(az containerapp list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

echo "📦 Container Registry: $CONTAINER_REGISTRY"
echo "⚡ Function App: $FUNCTION_APP"
echo "🐳 Container App: $CONTAINER_APP"
echo ""

# === Deploy Momentum Finder (Container App) ===
echo "🐳 Building and deploying Momentum Finder API..."
MOMENTUM_DIR="../momentum_finder"

if [ ! -d "$MOMENTUM_DIR" ]; then
    echo "📥 Cloning momentum_finder repository..."
    git clone https://github.com/skarumbu/momentum_finder.git "$MOMENTUM_DIR"
fi

cd "$MOMENTUM_DIR"

# Check for Dockerfile location
if [ -f "docker/dockerfile" ]; then
    echo "📝 Found Dockerfile in docker/ subdirectory"
    DOCKERFILE_PATH="docker/dockerfile"
    BUILD_CONTEXT="."
elif [ -f "Dockerfile" ]; then
    echo "📝 Found Dockerfile in root directory"
    DOCKERFILE_PATH="Dockerfile"
    BUILD_CONTEXT="."
else
    echo "❌ Error: Dockerfile not found in root or docker/ subdirectory"
    exit 1
fi

# Login to ACR
echo "🔐 Logging into Azure Container Registry..."
az acr login --name "$CONTAINER_REGISTRY"

# Build and push Docker image
echo "🏗️  Building Docker image..."
docker build -f "$DOCKERFILE_PATH" -t "${CONTAINER_REGISTRY_SERVER}/momentum-finder:latest" "$BUILD_CONTEXT"

echo "⬆️  Pushing to Azure Container Registry..."
docker push "${CONTAINER_REGISTRY_SERVER}/momentum-finder:latest"

# Update container app
echo "🔄 Updating Container App..."
az containerapp update \
  --name "$CONTAINER_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --image "${CONTAINER_REGISTRY_SERVER}/momentum-finder:latest"

cd ..

# === Deploy Digits API (Azure Functions) ===
echo ""
echo "⚡ Deploying Digits API (Azure Functions)..."
DIGITS_DIR="./digits"

if [ ! -d "$DIGITS_DIR" ]; then
    echo "📥 Cloning digits repository..."
    git clone https://github.com/skarumbu/digits.git "$DIGITS_DIR"
fi

cd "$DIGITS_DIR"

# Create Azure Functions structure if it doesn't exist
if [ ! -f "host.json" ]; then
    echo "📝 Creating Azure Functions configuration..."
    cat > host.json << 'EOF'
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  }
}
EOF

    cat > requirements.txt << 'EOF'
azure-functions
EOF

    # Create function for digits_creator
    mkdir -p digits_creator
    cat > digits_creator/function.json << 'EOF'
{
  "scriptFile": "../digits_creator.py",
  "bindings": [
    {
      "authLevel": "function",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["get", "post"]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ]
}
EOF

    # Create function for digits_solver
    mkdir -p digits_solver
    cat > digits_solver/function.json << 'EOF'
{
  "scriptFile": "../digits_solver.py",
  "bindings": [
    {
      "authLevel": "function",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["get", "post"]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ]
}
EOF

    echo "⚠️  Note: You may need to modify digits_creator.py and digits_solver.py"
    echo "   to use Azure Functions HTTP trigger format instead of Lambda format."
fi

# Deploy to Azure Functions
echo "⬆️  Deploying to Azure Functions..."
func azure functionapp publish "$FUNCTION_APP" --python

cd ..

echo ""
echo "✅ All APIs deployed successfully!"
echo "=================================="
echo ""
echo "🌐 Momentum Finder API URL:"
az containerapp show --name "$CONTAINER_APP" --resource-group "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv

echo ""
echo "⚡ Digits API URL:"
az functionapp show --name "$FUNCTION_APP" --resource-group "$RESOURCE_GROUP" --query "defaultHostName" -o tsv

echo ""
echo "Next step: Update your DNS records in Route 53"