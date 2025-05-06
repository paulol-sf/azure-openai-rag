param virtualNetworkName string = 'VNET-SeleneDev'
//param virtualNetworkResourceGroup string = 'RG-SeleneDev'
param newSubnetName string //= 'SNET-new-capps-env-preprod'
param newSubnetAddressPrefix string = '10.16.29.0/24' // Replace with the desired address prefix

param routeTables_route_southcentralus_dev_externalid string = '/subscriptions/39abda1a-7fc7-4042-9ae0-efed65f44d5c/resourceGroups/RG-Default-Networking/providers/Microsoft.Network/routeTables/route-southcentralus-dev'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: virtualNetworkName
}

resource newSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: virtualNetwork
  name: newSubnetName
  properties: {
    addressPrefix: newSubnetAddressPrefix
    routeTable: {
      id: routeTables_route_southcentralus_dev_externalid
    }
    delegations: [
      {
        name: 'Microsoft.App.environments'
        id: '${virtualNetwork.id}/delegations/Microsoft.App.environments'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'

  }
  //type: 'Microsoft.Network/virtualNetworks/subnets'
}

output id string = newSubnet.id
