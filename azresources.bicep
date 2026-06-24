@description('Specifies region of all resources.')
param location string = resourceGroup().location

@description('Suffix for function app, storage account, and key vault names.')
param appNameSuffix string = uniqueString(resourceGroup().id)

@description('Key Vault SKU name.')
param keyVaultSku string = 'Standard'

@description('Storage account SKU name.')
param storageSku string = 'Standard_LRS'

@description('Splunk HTTP Event Collector URL.')
param SPLUNK_HEC_URL string

@description('Splunk HTTP Event Collector token. Stored in Key Vault and referenced at runtime.')
@secure()
param SPLUNK_HEC_TOKEN string

@description('Splunk index to send events to.')
param SPLUNK_INDEX string

@description('Name of the webhook sender, used as the Splunk host field.')
param WEBHOOK_SENDER_NAME string

@description('Source or endpoint of the webhook sender, used as the Splunk source field.')
param WEBHOOK_SENDER_SOURCE string

@description('Sourcetype for events in Splunk.')
param WEBHOOK_SENDER_SOURCETYPE string = 'json'

@description('Webhook URL secret used to authenticate incoming webhooks. A new GUID is generated on each deployment if not provided, which will invalidate existing webhook URLs.')
@secure()
param webhookUrlSecret string = newGuid()

var functionAppName = 'azfunc-${appNameSuffix}'
var appServicePlanName = 'FunctionPlan-${appNameSuffix}'
var storageAccountName = 'fnstor${replace(appNameSuffix, '-', '')}'
var functionRuntime = 'node'
var keyVaultName = 'kv-${replace(appNameSuffix, '-', '')}'
var webhookUrlSecretName = 'webhookUrl'
var splunkHecTokenSecretName = 'SplunkHecToken'
var deploymentStorageContainerName = 'deployments'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: blobService
  name: deploymentStorageContainerName
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: 'StorageAccountConnectionString'
            storageAccountConnectionStringName: 'AzureWebJobsStorage'
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 512
        maximumInstanceCount: 1
      }
      runtime: {
        name: functionRuntime
        version: '24'
      }
    }
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'SPLUNK_HEC_URL'
          value: SPLUNK_HEC_URL
        }
        {
          // Key Vault reference — resolved at runtime using the function app's managed identity
          name: 'SPLUNK_HEC_TOKEN'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${splunkHecTokenSecretName})'
        }
        {
          // Key Vault reference — resolved at runtime using the function app's managed identity
          name: 'WEBHOOK_URL_SECRET'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=WebhookUrl)'
        }
        {
          name: 'SPLUNK_INDEX'
          value: SPLUNK_INDEX
        }
        {
          name: 'WEBHOOK_SENDER_NAME'
          value: WEBHOOK_SENDER_NAME
        }
        {
          name: 'WEBHOOK_SENDER_SOURCE'
          value: WEBHOOK_SENDER_SOURCE
        }
        {
          name: 'WEBHOOK_SENDER_SOURCETYPE'
          value: WEBHOOK_SENDER_SOURCETYPE
        }
      ]
    }
    httpsOnly: true
  }
}

// Key Vault — access policy grants the function app's managed identity read access to secrets
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: keyVaultSku
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

resource splunkHecTokenSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: splunkHecTokenSecretName
  properties: {
    value: SPLUNK_HEC_TOKEN
  }
}

resource webhookUrlHostSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: webhookUrlSecretName
  properties: {
    value: webhookUrlSecret
  }
}

output functionAppHostName string = functionApp.properties.defaultHostName
output functionAppName string = functionAppName
output keyVaultName string = keyVaultName
