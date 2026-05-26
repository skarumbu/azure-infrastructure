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
// Azure Static Web App
// ---------------------------------------------------------------------------

resource swa 'Microsoft.Web/staticSites@2022-09-01' = {
  name: 'running-app-${environment}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    repositoryUrl: 'https://github.com/skarumbu/running-app'
    branch: 'main'
    buildProperties: {
      appLocation: '/'
      apiLocation: 'api'
      outputLocation: 'build'
      appBuildCommand: 'npm run build'
    }
  }
}

// Google OAuth app settings on the SWA
resource swaAppSettings 'Microsoft.Web/staticSites/config@2022-09-01' = {
  parent: swa
  name: 'appsettings'
  properties: {
    GOOGLE_CLIENT_ID: googleClientId
    GOOGLE_CLIENT_SECRET: googleClientSecret
    DATABASE_URL: databaseUrl
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
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

resource runningAppDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: postgres
  name: 'running_app'
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Allow Azure services to connect (needed for Azure Functions)
resource firewallAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  parent: postgres
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output swaDefaultHostname string = swa.properties.defaultHostname
output swaName string = swa.name
output postgresHostname string = postgres.properties.fullyQualifiedDomainName
output postgresDatabaseName string = runningAppDb.name
