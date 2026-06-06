param location string
param environment string = 'prod'

@description('Azure Entra ID tenant ID for EasyAuth')
param azureTenantId string

@description('posts-api App Registration client ID')
param postsApiClientId string

@secure()
@description('posts-api App Registration client secret')
param postsApiClientSecret string

@secure()
@description('GitHub PAT with repo scope for writing posts')
param githubToken string

@description('GitHub repo in owner/repo format (e.g. skarumbu/my-website)')
param githubRepo string = 'skarumbu/my-website'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'postsapi${uniqueString(resourceGroup().id)}'
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

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'posts-api-${environment}-plan'
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
  name: 'posts-api-${environment}-${uniqueString(resourceGroup().id)}'
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
          value: 'posts-api-${environment}-content'
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
          name: 'POSTS_CLIENT_SECRET'
          value: postsApiClientSecret
        }
        {
          name: 'GITHUB_TOKEN'
          value: githubToken
        }
        {
          name: 'GITHUB_REPO'
          value: githubRepo
        }
      ]
      cors: {
        allowedOrigins: [
          'https://www.quixotry.me'
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
      requireAuthentication: false
      unauthenticatedClientAction: 'AllowAnonymous'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: postsApiClientId
          clientSecretSettingName: 'POSTS_CLIENT_SECRET'
          openIdIssuer: '${az.environment().authentication.loginEndpoint}${azureTenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${postsApiClientId}'
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
output functionPrincipalId string = functionApp.identity.principalId
output storageAccountName string = storageAccount.name
