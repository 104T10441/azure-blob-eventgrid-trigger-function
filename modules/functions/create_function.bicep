param deploymentParams object
param funcParams object
param tags object = resourceGroup().tags
param logAnalyticsWorkspaceId string
param enableDiagnostics bool = true

param saName string
param funcSaName string

param blobContainerName string

// Get Storage Account Reference
resource r_sa 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: saName
}
resource r_sa_1 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: funcSaName
}

resource r_fnHostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${funcParams.funcAppPrefix}-fnPlan-${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  kind: 'linux'
  sku: {
    // https://learn.microsoft.com/en-us/azure/azure-resource-manager/resource-manager-sku-not-available-errors
    name: funcParams.skuName
    tier: funcParams.funcHostingPlanTier
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

resource r_fnApp 'Microsoft.Web/sites@2021-03-01' = {
  name: '${funcParams.funcAppPrefix}-fnApp-${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  kind: 'functionapp,linux'
  tags: tags
  identity: {
    type: 'SystemAssigned'
    // type: 'SystemAssigned, UserAssigned'
    //   userAssignedIdentities: {
    //     '${identity.id}': {}
    //   }
  }
  properties: {
    enabled: true
    reserved: true
    serverFarmId: r_fnHostingPlan.id
    clientAffinityEnabled: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Python|3.10' //az webapp list-runtimes --linux || az functionapp list-runtimes --os linux -o table
      // ftpsState: 'FtpsOnly'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }

  }
  dependsOn: [
    r_applicationInsights
  ]
}

resource r_fnApp_settings 'Microsoft.Web/sites/config@2021-03-01' = {
  parent: r_fnApp
  name: 'appsettings' // Reservered Name
  properties: {
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${funcSaName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${r_sa_1.listKeys().keys[0].value}'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${funcSaName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${r_sa_1.listKeys().keys[0].value}'
    WEBSITE_CONTENTSHARE: toLower(funcParams.funcNamePrefix)
    APPINSIGHTS_INSTRUMENTATIONKEY: r_applicationInsights.properties.InstrumentationKey
    FUNCTIONS_WORKER_RUNTIME: 'python'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    // ENABLE_ORYX_BUILD: 'true'
    WAREHOUSE_STORAGE: 'DefaultEndpointsProtocol=https;AccountName=${saName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${r_sa.listKeys().keys[0].value}'
    SUBSCRIPTION_ID: subscription().subscriptionId
    RESOURCE_GROUP: resourceGroup().name
    DatabaseConnectionString: ''
  }
  dependsOn: [
    r_sa
    r_sa_1
  ]
}

resource r_fnApp_logs 'Microsoft.Web/sites/config@2021-03-01' = {
  parent: r_fnApp
  name: 'logs'
  properties: {
    applicationLogs: {
      azureBlobStorage: {
        level: 'Error'
        retentionInDays: 10
        // sasUrl: ''
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 100
        enabled: true
      }
    }
    detailedErrorMessages: {
      enabled: true
    }
    failedRequestsTracing: {
      enabled: true
    }
  }
}

// Create Function
resource r_fn_1 'Microsoft.Web/sites/functions@2022-03-01' = {
  name: '${funcParams.funcNamePrefix}-consumer-fn-${deploymentParams.global_uniqueness}'
  parent: r_fnApp
  properties: {
    // config_href: 'https://allotment-dev-uks-allotment-api.azurewebsites.net/admin/vfs/site/wwwroot/ConfirmEmail/function.json'
    invoke_url_template: 'https://${r_fnApp.name}.azurewebsites.net/api/sayhi'
    test_data: '{"method":"get","queryStringParams":[{"name":"miztiik-automation","value":"yes"}],"headers":[],"body":{"body":""}}'
    config: {
      disabled: false
      bindings: [
        // {
        //   "name": "blobTrigger",
        //   "type": "timerTrigger",
        //   "direction": "in",
        //   "schedule": "0 0 * * * *",
        //   "connnection": "AzureWebJobsStorage",
        //   "path": "blob/{test}"
        //  },
        // {
        //   authLevel: 'anonymous'
        //   type: 'httpTrigger'
        //   direction: 'in'
        //   name: 'req'
        //   webHookType: 'genericJson'
        //   methods: [
        //     'get'
        //     'post'
        //   ]
        // }
        {
          name: 'miztProc'
          type: 'blob'
          direction: 'in'
          path: '{data.url}'
          connection: 'WAREHOUSE_STORAGE'
          // datatype: 'binary'
        }
        {
          type: 'eventGridTrigger'
          name: 'event'
          direction: 'in'
        }
        {
          type: 'blob'
          direction: 'out'
          name: 'outputBlob'
          // path: '${blobContainerName}/processed/{DateTime}_{rand-guid}_{data.eTag}.json'
          path: '${blobContainerName}/processed/{DateTime}_{data.eTag}.json'
          connection: 'WAREHOUSE_STORAGE'
        }
        // {
        //   name: '$return'
        //   direction: 'out'
        //   type: 'http'
        // }
        // {
        //   type: 'queue'
        //   name: 'outputQueueItem'
        //   queueName: 'goodforstage1'
        //   connection: 'StorageAccountMain'
        //   direction: 'out'
        // }
        // {
        //   type: 'queue'
        //   name: 'outputQueueItemWithError'
        //   queueName: 'badforstage1'
        //   connection: 'StorageAccountMain'
        //   direction: 'out'
        // }
      ]
    }
    files: {
      // 'function.json': replace(loadTextContent('../../app/function_code/function.json'),'BLOB_CONTAINER_NAME', blobContainerName)
      '__init__.py': loadTextContent('../../app/function_code/__init__.py')
      'host.json': loadTextContent('../../app/function_code/host.json')
      'requirements.txt': loadTextContent('../../app/function_code/requirements.txt')
    }
  }
  dependsOn: [
    r_fnApp_settings
  ]
}
// var hostJson = loadTextContent('host.json')
// resource zipDeploy 'Microsoft.Web/sites/extensions@2022-03-01' = {
//   parent: r_fnApp
//   name:  any('ZipDeploy')
//   properties: {
//     packageUri: 'https://github.com/miztiik/azure-create-functions-with-bicep/raw/main/app8.zip'
//       template: {
//         hostJson: json(hostJson)
//       }
//   }
// }

// module app_service_webjob_msdeploy 'nested/microsoft.web/sites/extensions.bicep' = {
//   name: 'app-service-webjob-msdeploy'
//   params: {
//     appServiceName: dnsNamePrefix
//     webJobZipDeployUrl: azAppServiceWebJobZipUri
//   }
//   dependsOn: [
//     app_service_deploy
//   ]
// }


// Create Event Grid Subscription with Filter
// Event Grid topic
// resource r_eventGrid_topic 'Microsoft.EventGrid/topics@2022-06-15' = {
resource r_eventGrid_system_topic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: '${funcParams.funcNamePrefix}-eventGrid-Topic-${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  identity: {
    type: 'None'
  }
  properties: {
    source: r_sa.id
    topicType: 'microsoft.storage.storageaccounts'
    // dataResidencyBoundary: 'WithinRegion'
    // inputSchema: 'CloudEventSchemaV1_0'
    // publicNetworkAccess: 'Enabled'
  }
}



// Blob Change Log Subscription with filter
resource r_fn_1_eventGrid_subscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: r_eventGrid_system_topic
  name: '${funcParams.funcNamePrefix}-blob-ChangeLog-Subscription-${deploymentParams.global_uniqueness}'
  properties: {
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    destination: {
      endpointType: 'AzureFunction'
          properties: {
            resourceId: r_fn_1.id
            maxEventsPerBatch: 1
          preferredBatchSizeInKilobytes: 64
          }
    }
    filter: {
      //                    /blobServices/default/containers/containername/blobs/blobprefix
      subjectBeginsWith: '/blobServices/default/containers/${blobContainerName}/blobs/source'
      subjectEndsWith: '.json'
          includedEventTypes: [ 
            'Microsoft.Storage.BlobCreated'
            // 'Microsoft.Storage.BlobDeleted'
          ]
    }    
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}


// Function App Binding
resource r_fnAppBinding 'Microsoft.Web/sites/hostNameBindings@2022-03-01' = {
  parent: r_fnApp
  name: '${r_fnApp.name}.azurewebsites.net'
  properties: {
    siteName: r_fnApp.name
    hostNameType: 'Verified'
  }
}

// Adding Application Insights
resource r_applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${funcParams.funcNamePrefix}-fnAppInsights-${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Enabling Diagnostics for the Function
resource r_fnLogsToAzureMonitor 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: '${funcParams.funcNamePrefix}-logs-${deploymentParams.global_uniqueness}'
  scope: r_fnApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Functions Outputs
output fnName string = r_fn_1.name
output fnIdentity string = r_fnApp.identity.principalId
output fnAppUrl string = r_fnApp.properties.defaultHostName
output fnUrl string = r_fnApp.properties.defaultHostName
