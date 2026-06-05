targetScope = 'subscription'

@description('Primary location for all resources')
param location string = 'eastus'

@description('Environment name (dev, staging, prod)')
param environment string = 'prod'

@description('Your custom domain name')
param customDomain string = 'https://www.quixotry.me/'

@description('Momentum Finder container image. After first ACR push, pass the real image to avoid resetting to placeholder.')
param momentumFinderImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Trail Finder container image. After first ACR push, pass the real image to avoid resetting to placeholder.')
param trailFinderImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@secure()
@description('Google Places + Geocoding API key')
param googlePlacesApiKey string

@secure()
@description('Google Custom Search API key')
param googleSearchApiKey string

@secure()
@description('Google Programmable Search Engine ID')
param googleSearchEngineId string

@description('Name of the existing Azure AI Foundry (Cognitive Services) account')
param aiFoundryName string = 'trail-finder-foundry'

@description('Azure Entra ID tenant ID — from the App Registration created by setup-app-registration.sh')
param azureTenantId string

@description('App Registration client ID — from the App Registration created by setup-app-registration.sh')
param azureClientId string

@secure()
@description('App Registration client secret — from the App Registration created by setup-app-registration.sh')
param azureClientSecret string

@description('ideas-api App Registration client ID')
param ideasApiClientId string = 'bb744b67-4a31-41ab-a52b-006f90fce6cb'

@secure()
@description('ideas-api App Registration client secret')
param ideasApiClientSecret string

@secure()
@description('Shared write key for machine-to-machine writes (ideator job → ideas-api)')
param ideasApiWriteKey string

@description('posts-api App Registration client ID')
param postsApiClientId string

@secure()
@description('posts-api App Registration client secret')
param postsApiClientSecret string

@secure()
@description('GitHub fine-grained PAT for ideas-bot to push branches and open PRs')
param githubPat string

@secure()
@description('Google OAuth client ID for learning-plan-api token verification')
param googleClientId string

@description('CORS allowed origin for learning-plan-api (the SWA domain)')
param corsOrigin string = 'https://www.quixotry.me'

@description('Ideas bot container image. Updated after first ACR push.')
param ideasBotImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

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
    image: momentumFinderImage
  }
}

// Module: Trail Finder API (Container App)
module trailFinderAPI 'modules/trailfinder.bicep' = {
  scope: rg
  name: 'trailFinderDeployment'
  params: {
    location: location
    environment: environment
    containerRegistryName: containerRegistry.outputs.name
    containerAppEnvId: containerAppEnv.outputs.id
    image: trailFinderImage
    googlePlacesApiKey: googlePlacesApiKey
    googleSearchApiKey: googleSearchApiKey
    googleSearchEngineId: googleSearchEngineId
    aiFoundryName: aiFoundryName
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

// Module: Dashboard API (Azure Functions)
module dashboardAPI 'modules/dashboardapi.bicep' = {
  name: 'dashboardAPIDeployment'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceResourceId: containerAppEnv.outputs.logAnalyticsWorkspaceResourceId
    digitsMetricsConnectionString: digitsAPI.outputs.storageConnectionString
    momentumFinderUrl: momentumFinderAPI.outputs.url
    trailFinderUrl: trailFinderAPI.outputs.url
    azureTenantId: azureTenantId
    azureClientId: azureClientId
    azureClientSecret: azureClientSecret
  }
}

// Module: Ideas API (Azure Functions)
module ideasAPI 'modules/ideasapi.bicep' = {
  name: 'ideasAPIDeployment'
  scope: rg
  params: {
    location: location
    environment: environment
    azureTenantId: azureTenantId
    ideasApiClientId: ideasApiClientId
    ideasApiClientSecret: ideasApiClientSecret
    ideasApiWriteKey: ideasApiWriteKey
  }
}

// Module: Posts API (Azure Functions)
module postsAPI 'modules/postsapi.bicep' = {
  name: 'postsAPIDeployment'
  scope: rg
  params: {
    location: location
    environment: environment
    azureTenantId: azureTenantId
    postsApiClientId: postsApiClientId
    postsApiClientSecret: postsApiClientSecret
  }
}

// Module: Ideas Bot OpenAI resource
module ideasBotOpenAI 'modules/ideasbotopenai.bicep' = {
  name: 'ideasBotOpenAIDeployment'
  scope: rg
  params: {
    location: location
    environment: environment
  }
}

// Module: Learning Plan OpenAI resource
module learningPlanOpenAI 'modules/learningplanopenai.bicep' = {
  name: 'learningPlanOpenAIDeployment'
  scope: rg
  params: {
    location: location
  }
}

// Module: Learning Plan API (Azure Functions)
module learningPlanAPI 'modules/learningplanapi.bicep' = {
  name: 'learningPlanAPIDeployment'
  scope: rg
  params: {
    location: location
    environment: environment
    googleClientId: googleClientId
    azureOpenAiEndpoint: learningPlanOpenAI.outputs.endpoint
    azureOpenAiApiKey: learningPlanOpenAI.outputs.apiKey
    azureOpenAiDeploymentName: learningPlanOpenAI.outputs.deploymentName
    corsOrigin: corsOrigin
  }
}

// Module: Ideas Bot Container App Job
module ideasBot 'modules/ideasbot.bicep' = {
  name: 'ideasBotDeployment'
  scope: rg
  params: {
    location: location
    environment: environment
    containerRegistryName: containerRegistry.outputs.name
    containerAppEnvId: containerAppEnv.outputs.id
    ideasApiFunctionPrincipalId: ideasAPI.outputs.functionPrincipalId
    ideasApiUrl: ideasAPI.outputs.functionAppUrl
    azureOpenAiEndpoint: ideasBotOpenAI.outputs.endpoint
    azureOpenAiDeploymentName: ideasBotOpenAI.outputs.deploymentName
    azureOpenAiApiKey: ideasBotOpenAI.outputs.apiKey
    githubPat: githubPat
    ideasWriteKey: ideasApiWriteKey
    image: ideasBotImage
  }
}

// Cost Management Reader role assignment at subscription scope
module costMgmtRole 'modules/costmgmtrole.bicep' = {
  name: 'costMgmtRoleDeployment'
  params: {
    functionPrincipalId: dashboardAPI.outputs.functionPrincipalId
  }
}

// Outputs
output staticWebAppUrl string = staticWebApp.outputs.defaultHostname
output staticWebAppName string = staticWebApp.outputs.name
output momentumFinderUrl string = momentumFinderAPI.outputs.url
output trailFinderUrl string = trailFinderAPI.outputs.url
output digitsAPIUrl string = digitsAPI.outputs.functionAppUrl
output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output resourceGroupName string = rg.name
output ideasAPIUrl string = ideasAPI.outputs.functionAppUrl
output ideasAPIAppName string = ideasAPI.outputs.functionAppName
output learningPlanAPIUrl string = learningPlanAPI.outputs.functionAppUrl
output learningPlanAPIAppName string = learningPlanAPI.outputs.functionAppName
output postsAPIUrl string = postsAPI.outputs.functionAppUrl
output postsAPIAppName string = postsAPI.outputs.functionAppName
