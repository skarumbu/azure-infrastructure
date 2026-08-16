param location string
param environment string = 'prod'

@secure()
@description('GitHub PAT with repo scope for writing posts')
param githubToken string

@description('GitHub repo in owner/repo format (e.g. skarumbu/my-website)')
param githubRepo string = 'skarumbu/my-website'

@secure()
@description('Comma-separated Google OAuth client IDs accepted as token audience (posts-api self-verifies Google ID tokens; no Azure-level EasyAuth)')
param googleClientId string

@description('Comma-separated email allowlist for write access. Empty allows any authenticated Google account to write.')
param allowedWriters string = ''

@description('Name of the private blob container used for diary entries')
param diaryContainerName string = 'diary-entries'

@description('Base URL of history-api, including the /api prefix')
param historyApiUrl string

@secure()
@description('Shared write key for machine-to-machine writes to history-api (posts-api -> history-api)')
param historyApiWriteKey string

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

resource diaryContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  parent: blobService
  name: diaryContainerName
  properties: {
    publicAccess: 'None'
  }
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
          name: 'GITHUB_TOKEN'
          value: githubToken
        }
        {
          name: 'GITHUB_REPO'
          value: githubRepo
        }
        {
          name: 'GOOGLE_CLIENT_ID'
          value: googleClientId
        }
        {
          name: 'ALLOWED_WRITERS'
          value: allowedWriters
        }
        {
          name: 'POSTS_STORAGE_CONNECTION_STRING'
          value: storageConnectionString
        }
        {
          name: 'DIARY_CONTAINER_NAME'
          value: diaryContainerName
        }
        {
          name: 'HISTORY_API_URL'
          value: historyApiUrl
        }
        {
          name: 'HISTORY_API_KEY'
          value: historyApiWriteKey
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

output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionPrincipalId string = functionApp.identity.principalId
output storageAccountName string = storageAccount.name
