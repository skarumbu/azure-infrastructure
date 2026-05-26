param location string
param environment string = 'prod'

@secure()
param postgresAdminPassword string

@secure()
param googleClientId string

@secure()
param googleClientSecret string

@secure()
param databaseUrl string

// ---------------------------------------------------------------------------
// Azure Static Web App (Standard tier required for linked backend)
// ---------------------------------------------------------------------------

resource swa 'Microsoft.Web/staticSites@2022-09-01' = {
  name: 'running-app-${environment}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {}
}

// App settings on the SWA (used by frontend env; API settings live on the Function App)
resource swaAppSettings 'Microsoft.Web/staticSites/config@2022-09-01' = {
  parent: swa
  name: 'appsettings'
  properties: {
    GOOGLE_CLIENT_ID: googleClientId
    GOOGLE_CLIENT_SECRET: googleClientSecret
  }
}

// ---------------------------------------------------------------------------
// Standalone Azure Functions App (Python) — linked backend for /api/*
// ---------------------------------------------------------------------------

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'runapp${environment}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource plan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'running-app-${environment}-plan'
  location: location
  sku: { name: 'Y1', tier: 'Dynamic' }
  kind: 'functionapp'
  properties: { reserved: true }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: 'running-app-${environment}-api'
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'Python|3.11'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'running-app-${environment}-api-content'
        }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'true' }
        { name: 'DATABASE_URL', value: databaseUrl }
        { name: 'GOOGLE_CLIENT_ID', value: googleClientId }
      ]
      cors: {
        allowedOrigins: [ 'https://polite-sea-04fd3f210.7.azurestaticapps.net' ]
      }
    }
    httpsOnly: true
  }
}

// Link Function App to SWA so /api/* requests are proxied to it
resource linkedFunctionApp 'Microsoft.Web/staticSites/userProvidedFunctionApps@2022-09-01' = {
  parent: swa
  name: 'api'
  properties: {
    functionAppResourceId: functionApp.id
    functionAppRegion: location
  }
}

// ---------------------------------------------------------------------------
// Azure Database for PostgreSQL Flexible Server
// ---------------------------------------------------------------------------

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: 'running-app-db-${environment}'
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: 'runningadmin'
    administratorLoginPassword: postgresAdminPassword
    storage: { storageSizeGB: 32 }
    backup: { backupRetentionDays: 7, geoRedundantBackup: 'Disabled' }
    highAvailability: { mode: 'Disabled' }
  }
}

resource runningAppDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: postgres
  name: 'running_app'
  properties: { charset: 'UTF8', collation: 'en_US.utf8' }
}

resource firewallAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  parent: postgres
  name: 'AllowAzureServices'
  properties: { startIpAddress: '0.0.0.0', endIpAddress: '0.0.0.0' }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output swaDefaultHostname string = swa.properties.defaultHostname
output swaName string = swa.name
output functionAppName string = functionApp.name
output postgresHostname string = postgres.properties.fullyQualifiedDomainName
output postgresDatabaseName string = runningAppDb.name
