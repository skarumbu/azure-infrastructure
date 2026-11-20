param location string
param environment string = 'prod'
param containerRegistryName string
param containerAppEnvId string

@secure()
@description('api.data.gov key for the Congress.gov API; stored only as a Container App Job secret')
param congressApiKey string

@description('Sync job container image. Updated after first ACR push.')
param image string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Deployment package container name for Flex Consumption "run from package" deploys')
var deploymentContainerName = 'app-package-poligraph-api-${environment}'

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'poligraph${uniqueString(resourceGroup().id)}'
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

resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: deploymentContainerName
}

// Flex Consumption (FC1), same plan type as history-api.
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'poligraph-api-${environment}-plan'
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

// Public read-only API: no EasyAuth.
resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: 'poligraph-api-${environment}'
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
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
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: storageConnectionString
        }
      ]
      // Platform CORS answers the browser preflight for POST /api/lookup.
      cors: {
        allowedOrigins: [
          'https://www.quixotry.me'
          'http://localhost:3000'
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
        name: 'python'
        version: '3.11'
      }
    }
  }
}

resource syncJob 'Microsoft.App/jobs@2023-05-01' = {
  name: 'poligraph-sync-${environment}'
  location: location
  properties: {
    environmentId: containerAppEnvId
    configuration: {
      triggerType: 'Schedule'
      scheduleTriggerConfig: {
        cronExpression: '0 7 * * *'
        parallelism: 1
        replicaCompletionCount: 1
      }
      // 12h: covers the ~10h paced first sync.
      replicaTimeout: 43200
      replicaRetryLimit: 0
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'congress-api-key'
          value: congressApiKey
        }
        {
          name: 'storage-connection-string'
          value: storageConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'poligraph-sync'
          image: image
          env: [
            {
              name: 'CONGRESS_API_KEY'
              secretRef: 'congress-api-key'
            }
            {
              name: 'AZURE_STORAGE_CONNECTION_STRING'
              secretRef: 'storage-connection-string'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
    }
  }
}

output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output jobName string = syncJob.name
output storageAccountName string = storageAccount.name
