@description('Location for the OpenAI resource. gpt-4o-mini requires eastus.')
param location string = 'eastus'

var uniqueSuffix = take(uniqueString(resourceGroup().id, 'lplan-oai'), 8)

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'learning-plan-oai-${uniqueSuffix}'
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: 'learning-plan-oai-${uniqueSuffix}'
    publicNetworkAccess: 'Enabled'
  }
}

resource gpt4oMiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAiAccount
  name: 'gpt-4o-mini'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
  }
}

output endpoint string = openAiAccount.properties.endpoint
output apiKey string = openAiAccount.listKeys().key1
output deploymentName string = gpt4oMiniDeployment.name
