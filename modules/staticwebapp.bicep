param location string
param environment string
param customDomain string

resource staticWebApp 'Microsoft.Web/staticSites@2022-09-01' = {
  name: 'my-website-${environment}'
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    repositoryUrl: 'https://github.com/skarumbu/my-website'
    branch: 'main'
    buildProperties: {
      appLocation: '/'
      apiLocation: ''
      outputLocation: 'build'
      appBuildCommand: 'npm run build'
    }
  }
}

// Custom domain configuration (optional)
resource customDomainResource 'Microsoft.Web/staticSites/customDomains@2022-09-01' = if (customDomain != '') {
  parent: staticWebApp
  name: customDomain
  properties: {}
}

output defaultHostname string = staticWebApp.properties.defaultHostname
output name string = staticWebApp.name
output id string = staticWebApp.id
