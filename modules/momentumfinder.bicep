// modules/momentumfinder.bicep
param location string
param environment string
param containerRegistryName string
param containerAppEnvId string

@description('Container image to deploy. Defaults to a placeholder; pass the real ACR image after first push.')
param image string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

// Storage account for ML model files (downloaded by the app at startup)
resource modelStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'modelsst${uniqueString(resourceGroup().id)}'
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

resource modelsBlobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${modelStorageAccount.name}/default/models'
  properties: {
    publicAccess: 'None'
  }
}

resource momentumFinderApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'momentum-finder-${environment}'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvId
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
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
          name: 'model-storage-connection-string'
          value: 'DefaultEndpointsProtocol=https;AccountName=${modelStorageAccount.name};AccountKey=${modelStorageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'momentum-finder'
          image: image
          env: [
            {
              name: 'MODEL_STORAGE_CONNECTION_STRING'
              secretRef: 'model-storage-connection-string'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// Scheduled Container App Job for weekly model retraining.
// Runs inside Azure so stats.nba.com API calls are not blocked.
resource retrainJob 'Microsoft.App/jobs@2023-05-01' = {
  name: 'momentum-finder-retrain-${environment}'
  location: location
  properties: {
    environmentId: containerAppEnvId
    configuration: {
      triggerType: 'Schedule'
      scheduleTriggerConfig: {
        cronExpression: '0 6 * * 1'  // Every Monday at 6am UTC
        parallelism: 1
        replicaCompletionCount: 1
      }
      replicaTimeout: 7200  // 2 hour max runtime
      replicaRetryLimit: 1
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
          name: 'model-storage-connection-string'
          value: 'DefaultEndpointsProtocol=https;AccountName=${modelStorageAccount.name};AccountKey=${modelStorageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'retrain'
          image: image
          command: ['python', 'model_trainer.py']
          env: [
            {
              name: 'MODEL_STORAGE_CONNECTION_STRING'
              secretRef: 'model-storage-connection-string'
            }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
        }
      ]
    }
  }
}

output url string = 'https://${momentumFinderApp.properties.configuration.ingress.fqdn}'
output name string = momentumFinderApp.name
output modelStorageAccountName string = modelStorageAccount.name
output retrainJobName string = retrainJob.name
