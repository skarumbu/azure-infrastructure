targetScope = 'subscription'

@description('Principal ID of the dashboard API managed identity')
param functionPrincipalId string

resource costMgmtReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, functionPrincipalId, 'CostManagementReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '72fafb9e-0641-4937-9268-a91bfd8191a3')
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}
