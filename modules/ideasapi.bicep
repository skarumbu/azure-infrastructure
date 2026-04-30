param location string
param environment string = 'prod'

@description('Azure Entra ID tenant ID for EasyAuth')
param azureTenantId string

@description('ideas-api App Registration client ID (bb744b67-...)')
param ideasApiClientId string

@secure()
@description('ideas-api App Registration client secret')
param ideasApiClientSecret string

@secure()
@description('Shared write key for machine-to-machine writes from the ideator job')
param ideasApiWriteKey string

@description('Existing storage account name (created before Bicep management)')
param existingStorageAccountName string = 'ideasapiprodce2507b2'

@description('Existing app service plan name')
param existingAppServicePlanName string = 'ideas-api-prod-plan'

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: existingStorageAccountName
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
}

resource ideasTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2022-09-01' = {
  parent: tableService
  name: 'ideas'
}

resource projectsTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2022-09-01' = {
  parent: tableService
  name: 'projects'
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' existing = {
  name: existingAppServicePlanName
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: 'ideas-api-prod'
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
          value: 'ideas-api-${environment}-content'
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
          name: 'IDEAS_TABLE_CONNECTION_STRING'
          value: storageConnectionString
        }
        {
          name: 'IDEAS_WRITE_KEY'
          value: ideasApiWriteKey
        }
        {
          name: 'IDEAS_CLIENT_SECRET'
          value: ideasApiClientSecret
        }
        {
          name: 'BOT_JOB_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'BOT_JOB_RESOURCE_GROUP'
          value: resourceGroup().name
        }
        {
          name: 'BOT_JOB_NAME'
          value: 'ideas-bot-${environment}'
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
          clientId: ideasApiClientId
          clientSecretSettingName: 'IDEAS_CLIENT_SECRET'
          openIdIssuer: '${az.environment().authentication.loginEndpoint}${azureTenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${ideasApiClientId}'
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

resource tableStorageContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, 'StorageTableDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionPrincipalId string = functionApp.identity.principalId
