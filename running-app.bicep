// Standalone deployment for the running app.
// Deploy with:
//   az deployment sub create --location eastus --template-file running-app.bicep --parameters @running-app.parameters.json

targetScope = 'subscription'

@description('Primary location for all resources')
param location string = 'centralus'

@description('Environment name')
param environment string = 'prod'

@secure()
@description('Postgres admin password')
param postgresAdminPassword string

@secure()
@description('Google OAuth client ID (running-app OAuth client)')
param googleClientId string

@secure()
@description('Google OAuth client secret')
param googleClientSecret string

@secure()
@description('Full DATABASE_URL connection string for Azure Functions, e.g. postgresql://user:pass@host/db?sslmode=require')
param databaseUrl string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'running-app-${environment}-rg'
  location: location
}

module runningApp 'modules/runningapp.bicep' = {
  scope: rg
  name: 'runningAppDeployment'
  params: {
    location: location
    environment: environment
    postgresAdminPassword: postgresAdminPassword
    googleClientId: googleClientId
    googleClientSecret: googleClientSecret
    databaseUrl: databaseUrl
  }
}

output swaUrl string = runningApp.outputs.swaDefaultHostname
output postgresHostname string = runningApp.outputs.postgresHostname
output appInsightsConnectionString string = runningApp.outputs.appInsightsConnectionString
