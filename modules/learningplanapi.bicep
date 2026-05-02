param location string
param environment string = 'prod'

@secure()
@description('Google OAuth client ID used by the backend to verify ID tokens')
param googleClientId string

@description('Azure OpenAI endpoint URL (from learningplanopenai module output)')
param azureOpenAiEndpoint string

@secure()
@description('Azure OpenAI API key (from learningplanopenai module output)')
param azureOpenAiApiKey string

@description('Azure OpenAI deployment name (from learningplanopenai module output)')
param azureOpenAiDeploymentName string

@description('Allowed CORS origin (the SWA domain)')
param corsOrigin string = 'https://www.quixotry.me'

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'lplanst${uniqueString(resourceGroup().id)}'
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

resource learningPlansTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2022-09-01' = {
  parent: tableService
  name: 'LearningPlans'
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'learning-plan-api-plan-${environment}'
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
  name: 'learning-plan-api-${environment}-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'functionapp,linux'
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
          value: 'learning-plan-api-${environment}-content'
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
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: storageConnectionString
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: azureOpenAiEndpoint
        }
        {
          name: 'AZURE_OPENAI_API_KEY'
          value: azureOpenAiApiKey
        }
        {
          name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
          value: azureOpenAiDeploymentName
        }
        {
          name: 'GOOGLE_CLIENT_ID'
          value: googleClientId
        }
        {
          name: 'CORS_ORIGIN'
          value: corsOrigin
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

output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppName string = functionApp.name
