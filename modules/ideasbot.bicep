param location string
param environment string
param containerRegistryName string
param containerAppEnvId string
param ideasApiFunctionPrincipalId string
param ideasApiUrl string
param azureOpenAiEndpoint string
param azureOpenAiDeploymentName string
param azureOpenAiCodexDeploymentName string

@secure()
param azureOpenAiApiKey string

@secure()
param githubPat string

@secure()
param ideasWriteKey string

@description('Container image. Updated after first ACR push.')
param image string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

resource ideasBotJob 'Microsoft.App/jobs@2023-05-01' = {
  name: 'ideas-bot-${environment}'
  location: location
  properties: {
    environmentId: containerAppEnvId
    configuration: {
      triggerType: 'Manual'
      manualTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
      }
      replicaTimeout: 3600
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
          name: 'azure-openai-key'
          value: azureOpenAiApiKey
        }
        {
          name: 'github-pat'
          value: githubPat
        }
        {
          name: 'ideas-write-key'
          value: ideasWriteKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ideas-bot'
          image: image
          env: [
            {
              name: 'IDEAS_API_URL'
              value: ideasApiUrl
            }
            {
              name: 'GITHUB_USERNAME'
              value: 'skarumbu'
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: azureOpenAiEndpoint
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT'
              value: azureOpenAiDeploymentName
            }
            {
              name: 'AZURE_OPENAI_CODEX_DEPLOYMENT'
              value: azureOpenAiCodexDeploymentName
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'azure-openai-key'
            }
            {
              name: 'GITHUB_PAT'
              secretRef: 'github-pat'
            }
            {
              name: 'GH_TOKEN'
              secretRef: 'github-pat'
            }
            {
              name: 'IDEAS_WRITE_KEY'
              secretRef: 'ideas-write-key'
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

resource ideasApiRunnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: ideasBotJob
  name: guid(ideasBotJob.id, ideasApiFunctionPrincipalId, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: ideasApiFunctionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output jobName string = ideasBotJob.name
