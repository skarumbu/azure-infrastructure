// modules/trailfinder.bicep
param location string
param environment string
param containerRegistryName string
param containerAppEnvId string

@description('Container image to deploy. Defaults to a placeholder; pass the real ACR image after first push.')
param image string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Name of the existing Azure AI Foundry (Cognitive Services) account')
param aiFoundryName string

@secure()
param googlePlacesApiKey string

@secure()
param googleSearchApiKey string

@secure()
param googleSearchEngineId string

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aiFoundryName
}

resource trailFinderApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'trail-finder-${environment}'
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
          name: 'google-places-api-key'
          value: googlePlacesApiKey
        }
        {
          name: 'google-search-api-key'
          value: googleSearchApiKey
        }
        {
          name: 'google-search-engine-id'
          value: googleSearchEngineId
        }
        {
          name: 'azure-openai-api-key'
          value: aiFoundry.listKeys().key1
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'trail-finder'
          image: image
          env: [
            {
              name: 'GOOGLE_PLACES_API_KEY'
              secretRef: 'google-places-api-key'
            }
            {
              name: 'GOOGLE_SEARCH_API_KEY'
              secretRef: 'google-search-api-key'
            }
            {
              name: 'GOOGLE_SEARCH_ENGINE_ID'
              secretRef: 'google-search-engine-id'
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'azure-openai-api-key'
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: aiFoundry.properties.endpoint
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT'
              value: 'gpt-4o-mini'
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

output url string = 'https://${trailFinderApp.properties.configuration.ingress.fqdn}'
output name string = trailFinderApp.name
