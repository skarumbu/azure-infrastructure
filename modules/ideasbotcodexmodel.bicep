// Deployed independently from modules/ideasbotopenai.bicep (separate az deployment
// group create step) so that InsufficientQuota on this model doesn't block preflight
// validation of the rest of the infra. Remove this comment once quota is granted
// and the split is no longer needed.

var uniqueSuffix = take(uniqueString(resourceGroup().id, 'ideasbot-oai'), 8)

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: 'ideas-bot-oai-${uniqueSuffix}'
}

resource gpt53CodexDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAiAccount
  name: 'gpt-5.3-codex'
  sku: {
    name: 'GlobalStandard'
    capacity: 50
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.3-codex'
      version: '2026-02-24'
    }
  }
}

output deploymentName string = gpt53CodexDeployment.name
