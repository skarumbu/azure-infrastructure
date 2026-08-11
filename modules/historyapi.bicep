param location string
param environment string = 'prod'

@description('Azure Entra ID tenant ID for EasyAuth')
param azureTenantId string

@description('history-api App Registration client ID')
param historyApiClientId string

@secure()
@description('history-api App Registration client secret')
param historyApiClientSecret string

@secure()
@description('Shared write key for machine-to-machine writes (wiki-update-pr workflow, posts-api)')
param historyApiWriteKey string

@description('Deployment package container name for Flex Consumption "run from package" deploys')
var deploymentContainerName = 'app-package-history-api-${environment}'

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'historyapi${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource attachmentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'history-attachments'
}

resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: deploymentContainerName
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource versionsTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-01-01' = {
  parent: tableService
  name: 'versions'
}

// Flex Consumption (FC1) — the only plan Go's public preview runs on; not the
// classic Y1/Consumption plan every other function app in this org uses.
// See history-api's docs/design/2026-08-09-history-api-design.md.
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'history-api-${environment}-plan'
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: 'history-api-${environment}'
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      // Required during the Go worker's public preview.
      http20Enabled: false
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          value: storageConnectionString
        }
        {
          name: 'HISTORY_TABLE_CONNECTION_STRING'
          value: storageConnectionString
        }
        {
          name: 'HISTORY_BLOB_CONNECTION_STRING'
          value: storageConnectionString
        }
        {
          name: 'HISTORY_WRITE_KEY'
          value: historyApiWriteKey
        }
        {
          name: 'HISTORY_CLIENT_SECRET'
          value: historyApiClientSecret
        }
      ]
      cors: {
        allowedOrigins: [
          'https://www.quixotry.me'
        ]
      }
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${deploymentContainerName}'
          authentication: {
            type: 'StorageAccountConnectionString'
            storageAccountConnectionStringName: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'go'
        version: '1.0'
      }
    }
  }
}

resource authSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: functionApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: false
      unauthenticatedClientAction: 'AllowAnonymous'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: historyApiClientId
          clientSecretSettingName: 'HISTORY_CLIENT_SECRET'
          openIdIssuer: '${az.environment().authentication.loginEndpoint}${azureTenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${historyApiClientId}'
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

output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output storageAccountName string = storageAccount.name
