param location string
param logAnalyticsWorkspaceResourceId string
param digitsMetricsConnectionString string
param momentumFinderUrl string
param trailFinderUrl string

@description('Environment name (dev, staging, prod)')
param environment string = 'prod'

var uniqueSuffix = take(uniqueString(resourceGroup().id, 'dashboard'), 10)

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'dashboardst${uniqueSuffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'dashboard-plan-${environment}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
  kind: 'functionapp'
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: 'dashboard-api-prod-${uniqueSuffix}'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'Python|3.11'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'dashboard-api-${environment}-content'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'LOG_ANALYTICS_WORKSPACE_ID'
          value: logAnalyticsWorkspaceResourceId
        }
        {
          name: 'DIGITS_METRICS_CONNECTION_STRING'
          value: digitsMetricsConnectionString
        }
        {
          name: 'MOMENTUM_FINDER_URL'
          value: momentumFinderUrl
        }
        {
          name: 'TRAIL_FINDER_URL'
          value: trailFinderUrl
        }
        {
          name: 'AZURE_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'AZURE_RESOURCE_GROUP'
          value: resourceGroup().name
        }
      ]
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
    }
    httpsOnly: true
  }
}

resource logAnalyticsReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(logAnalyticsWorkspaceResourceId, functionApp.id, 'LogAnalyticsReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '73c42c96-874c-492b-b04d-ab87d138a893')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    functionApp
  ]
}

resource monitoringReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, 'MonitoringReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    functionApp
  ]
}

output functionPrincipalId string = functionApp.identity.principalId
output functionAppName string = functionApp.name
