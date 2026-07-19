param location string
param environment string

var uniqueSuffix = take(uniqueString(resourceGroup().id, 'ideasbot-oai'), 8)

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'ideas-bot-oai-${uniqueSuffix}'
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: 'ideas-bot-oai-${uniqueSuffix}'
    publicNetworkAccess: 'Enabled'
  }
}

resource gpt41Deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAiAccount
  name: 'gpt-4.1'
  sku: {
    name: 'GlobalStandard'
    capacity: 50
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1'
      version: '2025-04-14'
    }
  }
}

resource gpt41MiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAiAccount
  name: 'gpt-4.1-mini'
  dependsOn: [gpt41Deployment]
  sku: {
    name: 'GlobalStandard'
    capacity: 100
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1-mini'
      version: '2025-04-14'
    }
  }
}

// gpt-5.3-codex is deployed separately via modules/ideasbotcodexmodel.bicep
// (its own az deployment group create step) because it's gated on a quota
// grant that isn't approved yet — keeping it out of this template means a
// quota failure there can't block preflight validation of the rest of main.bicep.

output endpoint string = openAiAccount.properties.endpoint
output apiKey string = openAiAccount.listKeys().key1
output deploymentName string = gpt41Deployment.name
