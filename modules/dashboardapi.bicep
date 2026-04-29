param location string
param logAnalyticsWorkspaceResourceId string
param digitsMetricsConnectionString string
param momentumFinderUrl string
param trailFinderUrl string

@description('Environment name (dev, staging, prod)')
param environment string = 'prod'

@description('Azure Entra ID tenant ID for EasyAuth and OBO credential')
param azureTenantId string

@description('App Registration client ID for EasyAuth and OBO credential')
param azureClientId string

@secure()
@description('App Registration client secret for EasyAuth and OBO credential')
param azureClientSecret string

var uniqueSuffix = take(uniqueString(resourceGroup().id, 'dashboard'), 10)
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

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

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
}

resource registeredAppsTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2022-09-01' = {
  parent: tableService
  name: 'registeredapps'
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
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
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
        {
          name: 'AZURE_TENANT_ID'
          value: azureTenantId
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: azureClientId
        }
        {
          name: 'AZURE_CLIENT_SECRET'
          value: azureClientSecret
        }
        {
          name: 'REGISTRY_TABLE_CONNECTION_STRING'
          value: storageConnectionString
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

// EasyAuth: validate Azure AD tokens, return 401 for unauthenticated requests,
// and enable token store so X-MS-TOKEN-AAD-ACCESS-TOKEN is injected per request.
resource authSettings 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: functionApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: azureClientId
          clientSecretSettingName: 'AZURE_CLIENT_SECRET'
          openIdIssuer: '${az.environment().authentication.loginEndpoint}${azureTenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${azureClientId}'
          ]
        }
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}

resource logAnalyticsReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(logAnalyticsWorkspaceResourceId, functionApp.id, 'LogAnalyticsReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '73c42c96-874c-492b-b04d-ab87d138a893')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource monitoringReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, 'MonitoringReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Allows the Managed Identity to read/write the registeredapps Table Storage table.
resource tableStorageContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, 'StorageTableDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output functionPrincipalId string = functionApp.identity.principalId
output functionAppName string = functionApp.name
