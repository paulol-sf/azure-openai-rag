metadata description = 'Creates an Azure Container Apps environment.'
param name string
param location string = resourceGroup().location
param tags object = {}

@description('Name of the Application Insights resource')
param applicationInsightsName string = ''

@description('Specifies if Dapr is enabled')
param daprEnabled bool = false

@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string

//param managedEnvironments_cappsenv_flw_preprod_name string = 'cappsenv-flw-preprod'
//param virtualNetworks_VNET_SeleneDev_externalid string = '/subscriptions/39abda1a-7fc7-4042-9ae0-efed65f44d5c/resourceGroups/RG-SeleneDev/providers/Microsoft.Network/virtualNetworks/VNET-SeleneDev'
param newSubnetName string

module newSubnet '../network/cappenv-subnet.bicep' = {
  name: '${deployment().name}-subnet-create'
  scope: resourceGroup('RG-SeleneDev')
  params: {
    newSubnetName: newSubnetName
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: newSubnet.outputs.id
      //infrastructureSubnetId: '${virtualNetworks_VNET_SeleneDev_externalid}/subnets/SNET-capps-env-preprod'
    }
    //appLogsConfiguration: {}
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    //daprAIInstrumentationKey: daprEnabled && !empty(applicationInsightsName) ? applicationInsights.properties.InstrumentationKey : ''
    zoneRedundant: false
    kedaConfiguration: {}
    daprConfiguration: {}
    customDomainConfiguration: {}
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
        //enableFips: false
      }
    ]
    infrastructureResourceGroup: '${resourceGroup().name}-infra'
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
    //publicNetworkAccess: 'Enabled'
  }
}
/*
resource managedEnvironments_cappsenv_flw_preprod_name_selene 'Microsoft.App/managedEnvironments/certificates@2025-01-01' = {
  parent: containerAppsEnvironment
  name: 'selene'
  location: 'southcentralus'
  properties: {}
}
*/
/*
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    daprAIInstrumentationKey: daprEnabled && !empty(applicationInsightsName) ? applicationInsights.properties.InstrumentationKey : ''
  }
}
*/
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (daprEnabled && !empty(applicationInsightsName)) {
  name: applicationInsightsName
}

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output id string = containerAppsEnvironment.id
output name string = containerAppsEnvironment.name
/*
resource managedEnvironments_cappsenv_flw_preprod_name_selene 'Microsoft.App/managedEnvironments/certificates@2024-10-02-preview' = {
  parent: containerAppsEnvironment
  name: 'selene'
  location: 'southcentralus'
  properties: {
    certificateType: 'ServerSSLCertificate'
  }
}
*/
