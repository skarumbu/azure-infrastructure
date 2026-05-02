param location string

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

resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAiAccount
  name: 'gpt-4o'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
  }
}

output endpoint string = openAiAccount.properties.endpoint
output apiKey string = openAiAccount.listKeys().key1
output deploymentName string = gpt4oDeployment.name
