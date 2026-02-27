targetScope = 'subscription'

@description('Primary location for all resources')
param location string = 'eastus'

@description('Environment name (dev, staging, prod)')
param environment string = 'prod'

@description('Your custom domain name')
param customDomain string = 'https://www.quixotry.me/'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'my-website-${environment}-rg'
  location: location
}

// Module: Static Web App (React Frontend)
module staticWebApp 'modules/staticwebapp.bicep' = {
  scope: rg
  name: 'staticWebAppDeployment'
  params: {
    location: location
    environment: environment
    customDomain: customDomain
  }
}

// Module: Container Registry
module containerRegistry 'modules/containerregistry.bicep' = {
  scope: rg
  name: 'containerRegistryDeployment'
  params: {
    location: location
    environment: environment
  }
}

// Module: Container App Environment
module containerAppEnv 'modules/containerappenvironment.bicep' = {
  scope: rg
  name: 'containerAppEnvDeployment'
  params: {
    location: location
    environment: environment
  }
}

// Module: Momentum Finder API (Container App)
module momentumFinderAPI 'modules/momentumfinder.bicep' = {
  scope: rg
  name: 'momentumFinderDeployment'
  params: {
    location: location
    environment: environment
    containerRegistryName: containerRegistry.outputs.name
    containerAppEnvId: containerAppEnv.outputs.id
  }
}

// Module: Azure Functions for Digits APIs
module digitsAPI 'modules/digitsfunctions.bicep' = {
  scope: rg
  name: 'digitsAPIDeployment'
  params: {
    location: location
    environment: environment
  }
}

// Outputs
output staticWebAppUrl string = staticWebApp.outputs.defaultHostname
output staticWebAppName string = staticWebApp.outputs.name
output momentumFinderUrl string = momentumFinderAPI.outputs.url
output digitsAPIUrl string = digitsAPI.outputs.functionAppUrl
output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output resourceGroupName string = rg.name
