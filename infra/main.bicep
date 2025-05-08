targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param resourceGroupName string = ''
//param frontendName string = 'frontend'
param backendApiName string = 'flowable-enterprise'
//param backendApiImageName string = 'rulesenginecontainerregistrydev.azurecr.io/repo.flowable.com/docker/flowable/flowable-work:3.17.3'
//param ingestionApiName string = 'ingestion'
//param ingestionApiImageName string = ''
//param qdrantName string = 'qdrant'
//param qdrantImageName string = 'docker.io/qdrant/qdrant:v1.12.0'

// The free tier does not support managed identity (required) or semantic search (optional)
/*
@allowed(['basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param searchServiceSkuName string // Set in main.parameters.json

@description('Location for the OpenAI resource group')
@allowed(['australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth', 'westeurope'])
@metadata({
  azd: {
    type: 'location'
  }
})
  
param openAiLocation string // Set in main.parameters.json
param openAiUrl string = ''
param openAiSkuName string = 'S0'
param openAiApiVersion string // Set in main.parameters.json
*/
// Location is not relevant here as it's only for the built-in api
// which is not used here. Static Web App is a global service otherwise
/*
@description('Location for the Static Web App')
@allowed(['westus2', 'centralus', 'eastus2', 'westeurope', 'eastasia', 'eastasiastage'])
@metadata({
  azd: {
    type: 'location'
  }
})
param frontendLocation string = 'eastus2'

param chatModelName string // Set in main.parameters.json
param chatDeploymentName string = chatModelName
param chatModelVersion string // Set in main.parameters.json
param chatDeploymentCapacity int = useAzureFree ? 1 : 15
param embeddingsModelName string // Set in main.parameters.json
param embeddingsModelVersion string // Set in main.parameters.json
param embeddingsDeploymentName string = embeddingsModelName
param embeddingsDeploymentCapacity int = useAzureFree ? 1 : 30
*/
@description('Id of the user or app to assign application roles')
param principalId string = ''
/*
@description('Use Qdrant as the vector DB')
param useQdrant bool = false

@description('Qdrant port')
param qdrantPort int // Set in main.parameters.json
*/
@description('Use Azure Free tier')
param useAzureFree bool = false

// Differentiates between automated and manual deployments
param isContinuousDeployment bool = false

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
//var finalOpenAiUrl = empty(openAiUrl) ? 'https://${openAi.outputs.name}.openai.azure.com' : openAiUrl
//var useAzureAISearch = !useQdrant
//var qdrantUrl = useQdrant ? (qdrantPort == 6334 ? replace('${qdrant.outputs.uri}:80', 'https', 'http') : '${qdrant.outputs.uri}:443') : ''

//var ingestionApiIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}ingestion-api-${resourceToken}'
//var backendApiIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}backend-api-${resourceToken}'
var flwWorkIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}flowable-work-${resourceToken}'
var flwDesignIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}flowable-design-${resourceToken}'
var flwControlIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}flowable-control-${resourceToken}'
//var qdrantIdentityName = '${abbrs.managedIdentityUserAssignedIdentities}qdrant-${resourceToken}'
//var searchUrl = useQdrant ? '' : 'https://${searchService.outputs.name}.search.windows.net'
//var openAiInstanceName = empty(openAiUrl) ? openAi.outputs.name : ''

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
  }
}

// Container apps host (including container registry)
module containerApps './core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'containerapps'
    containerAppsEnvironmentName: '${abbrs.appManagedEnvironments}${resourceToken}'
    //containerRegistryName: '${abbrs.containerRegistryRegistries}${resourceToken}'
    newSubnetName: '${abbrs.networkVirtualNetworksSubnets}${resourceGroup.name}-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    //containerRegistryAdminUserEnabled: true
  }
}

// The application frontend
/*
module frontend './core/host/staticwebapp.bicep' = {
  name: 'frontend'
  scope: resourceGroup
  params: {
    name: !empty(frontendName) ? frontendName : '${abbrs.webStaticSites}web-${resourceToken}'
    location: frontendLocation
    tags: union(tags, { 'azd-service-name': frontendName })
  }
}
*/
// Flowable Work identity
module FlowableWorkIdentity 'core/security/managed-identity.bicep' = {
  //name: 'backend-api-identity'
  name: 'flowable-work-identity'
  scope: resourceGroup
  params: {
    name: flwWorkIdentityName
    location: location
  }
}

// Flowable Design identity
module FlowableDesignIdentity 'core/security/managed-identity.bicep' = {
  name: 'flowable-design-identity'
  scope: resourceGroup
  params: {
    name: flwDesignIdentityName
    location: location
  }
}

// Flowable Control identity
module FlowableControlIdentity 'core/security/managed-identity.bicep' = {
  name: 'flowable-control-identity'
  scope: resourceGroup
  params: {
    name: flwControlIdentityName
    location: location
  }
}

// Flowable Work App
module flowableWork './core/host/container-app.bicep' = {
  name: 'flowable-work'
  scope: resourceGroup
  params: {
    name: '${abbrs.appContainerApps}flw-work-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': backendApiName })
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    //containerRegistryName: containerApps.outputs.registryName
    containerRegistryName: 'rulesenginecontainerregistrydev'
    identityName: flwWorkIdentityName
    //allowedOrigins: [frontend.outputs.uri]
    allowedOrigins: ['*']
    containerCpuCoreCount: '2.0'
    containerMemory: '4.0Gi'
    secrets: {
      'appinsights-cs': monitoring.outputs.applicationInsightsConnectionString
    }
    env: [
      {
        name: 'FLOWABLE_INSPECT_ENABLED'
        value: 'true'
      }
      {
        name: 'FLOWABLE_INDEXING_ENABLED'
        value: 'false'
      }
      {
        name: 'MANAGEMENT_METRICS_EXPORT_ELASTIC_ENABLED'
        value: 'false'
      }
      {
        name: 'MANAGEMENT_HEALTH_ELASTICSEARCH_ENABLED'
        value: 'false'
      }
      {
        name: 'SERVER_SERVLET_CONTEXT_PATH'
        value: '/flowable-work'
      }
      {
        name: 'SPRING_DATASOURCE_DRIVER_CLASS_NAME'
        value: 'org.postgresql.Driver'
      }
      {
        name: 'SPRING_DATASOURCE_URL'
        value: 'jdbc:postgresql://psql-flw-nonprod02-flex.postgres.database.azure.com:5432/flw_ent_work_dev'
      }
      {
        name: 'SPRING_DATASOURCE_USERNAME'
        value: 'flw_work_dev'
      }
      {
        name: 'SPRING_DATASOURCE_PASSWORD'
        value: 'Today@031125'
      }
    ]
    imageName: 'rulesenginecontainerregistrydev.azurecr.io/repo.flowable.com/docker/flowable/flowable-work:3.17.3'
    targetPort: 8080
  }
}

// Flowable Design App
module flowableDesign './core/host/container-app.bicep' = {
  name: 'flowable-design'
  scope: resourceGroup
  params: {
    name: '${abbrs.appContainerApps}flw-design-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': backendApiName })
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    //containerRegistryName: containerApps.outputs.registryName
    containerRegistryName: 'rulesenginecontainerregistrydev'
    identityName: flwDesignIdentityName
    //allowedOrigins: [frontend.outputs.uri]
    allowedOrigins: ['*']
    containerCpuCoreCount: '2.0'
    containerMemory: '4.0Gi'
    secrets: {
      'appinsights-cs': monitoring.outputs.applicationInsightsConnectionString
    }
    env: [
      {
        name: 'FLOWABLE_DESIGN_REMOTE_AUTHENTICATION_USER'
        value: 'admin'
      }
      {
        name: 'FLOWABLE_DESIGN_REMOTE_AUTHENTICATION_PASSWORD'
        value: 'Today@0327'
      }
      {
        name: 'FLOWABLE_DESIGN_REMOTE_IDM_URL'
        value: '${flowableWork.outputs.uri}/flowable-work'
      }
      {
        name: 'FLOWABLE_DESIGN_DEPLOYMENT_API_URL'
        value: '${flowableWork.outputs.uri}/flowable-work/app-api'
      }
      {
        name: 'FLOWABLE_DESIGN_UNDEPLOYMENT_API_URL'
        value: '${flowableWork.outputs.uri}/flowable-work/platform-api/app-deployments'
      }
      {
        name: 'FLOWABLE_DESIGN_DB_STORE_ENABLED'
        value: 'true'
      }
      {
        name: 'SPRING_DATASOURCE_DRIVER_CLASS_NAME'
        value: 'org.postgresql.Driver'
      }
      {
        name: 'SPRING_DATASOURCE_URL'
        value: 'jdbc:postgresql://psql-flw-nonprod02-flex.postgres.database.azure.com:5432/flw_ent_design_dev'
      }
      {
        name: 'SPRING_DATASOURCE_USERNAME'
        value: 'flw_design_dev'
      }
      {
        name: 'SPRING_DATASOURCE_PASSWORD'
        value: 'Today@031125'
      }
    ]
    imageName: 'rulesenginecontainerregistrydev.azurecr.io/repo.flowable.com/docker/flowable/flowable-design:3.17.3'
    targetPort: 8080
  }
}

// Flowable Control App
module flowableControl './core/host/container-app.bicep' = {
  name: 'flowable-control'
  scope: resourceGroup
  params: {
    name: '${abbrs.appContainerApps}flw-control-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': backendApiName })
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    //containerRegistryName: containerApps.outputs.registryName
    containerRegistryName: 'rulesenginecontainerregistrydev'
    identityName: flwControlIdentityName
    //allowedOrigins: [frontend.outputs.uri]
    allowedOrigins: ['*']
    containerCpuCoreCount: '2.0'
    containerMemory: '4.0Gi'
    secrets: {
      'appinsights-cs': monitoring.outputs.applicationInsightsConnectionString
    }
    env: [
      {
        name: 'FLOWABLE_COMMON_APP_IDM_ADMIN_USER'
        value: 'admin'
      }
      {
        name: 'FLOWABLE_COMMON_APP_IDM_ADMIN_PASSWORD'
        value: 'test'
      }
      {
        name: 'FLOWABLE_CONTROL_APP_CLUSTER_CONFIG_SERVER_ADDRESS'
        value: '${flowableWork.outputs.uri}'
      }
      {
        name: 'FLOWABLE_CONTROL_APP_CLUSTER_CONFIG_PORT'
        value: '443'
      }
      {
        name: 'FLOWABLE_CONTROL_APP_CLUSTER_CONFIG_CONTEXT_ROOT'
        value: 'flowable-work'
      }
      {
        name: 'FLOWABLE_CONTROL_APP_CLUSTER_CONFIG_PASSWORD'
        value: 'Today@0327'
      }
      {
        name: 'SPRING_DATASOURCE_DRIVER_CLASS_NAME'
        value: 'org.postgresql.Driver'
      }
      {
        name: 'SPRING_DATASOURCE_URL'
        value: 'jdbc:postgresql://psql-flw-nonprod02-flex.postgres.database.azure.com:5432/flw_ent_control_preprod'
      }
      {
        name: 'SPRING_DATASOURCE_USERNAME'
        value: 'flw_control_preprod'
      }
      {
        name: 'SPRING_DATASOURCE_PASSWORD'
        value: 'Today@031125'
      }
    ]
    imageName: 'rulesenginecontainerregistrydev.azurecr.io/repo.flowable.com/docker/flowable/flowable-control:3.17.3'
    targetPort: 8080
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name

output FLOWABLE_WORK_API_URI string = flowableWork.outputs.uri
output FLOWABLE_DESIGN_API_URI string = flowableDesign.outputs.uri
output FLOWABLE_CONTROL_API_URI string = flowableControl.outputs.uri
