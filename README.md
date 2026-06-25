## About

Easy to deploy Azure Function App to expose the Splunk HTTP Event Collector (HEC API) as a webhook endpoint for applications that do not have native integration with Splunk. This can be used where it is not possible or unfeasible to directly send events to Splunk, such as 3rd party systems and legacy applications.

This open-source tool is intended to be deployed for any Azure & Splunk Enterprise 6.3.0+ or Splunk Cloud Platform environment, sample data and endpoint declarations are available below for deploying within the UIUC environment.

## Data Sources

For data sensitivity, see [Data Classification](https://www.cybersecurity.illinois.edu/data-classification/). Substitute (Your Application) with the application which will be sending webhook payloads to this application.

| Data Store         | Data Type                 | Sensitivity                       | Notes                                                                                                           |
| ------------------ | ------------------------- | --------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| (Your Application) | (data sent from your app) | (Appropriate Data Classification) | This application will injest data sent to it via webhook. Data is transmitted to Splunk endpoint defined below. |

## Endpoint Connections

This application's public endpoint URL is configured during deployment to your own Azure App Service Plan.

| Endpoint                                                        | Purpose                         | Stage | Access               | Contact                                                                                  |
| --------------------------------------------------------------- | ------------------------------- | ----- | -------------------- | ---------------------------------------------------------------------------------------- |
| https://http-inputs-illinois.splunkcloud.com/services/collector | Splunk HTTP Event Collector API | prod  | Outbound HTTPS, POST | Splunk service team<br>[splunk-support@illinois.edu](mailto:splunk-support@illinois.edu) |
| (Function URL)                                                  | Webhook receiver                | prod  | Inbound HTTPS, POST  | (Your Azure admin)                                                                       |

## Product Support

This product is supported by James Harrell ([jharrell@illinois.edu](mailto:jharrell@illinois.edu)) on a best-effort basis.

As of the last update to this README, the expected End-of-Life and
End-of-Support dates of this product are 2028 April.

End-of-Life was decided upon based on these dependencies:

- Node.js 24.16.0 LTS (2028 April 30)
- Azure Functions v4 Runtime (end-of-life TBD)
- Bicep resources schemas (varies per resource, TBD)
- Splunk collector API (TBD)

# Getting Started

## Software Prerequisites

1. Install Node.js v24.16.0 LTS: [Node Download Archive](https://nodejs.org/en/download/archive/v24.16.0)
2. Install Azure CLI: [Microsoft Learn article](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
3. Install Azure Functions Core Tools: [Microsoft Learn article](https://learn.microsoft.com/en-us/azure/azure-functions/how-to-create-function-azure-cli?pivots=programming-language-csharp&tabs=windows%2Cbash%2Cazure-cli#prerequisites)

## Basic Setup

### 1. Clone the repo:

```
git clone https://github.com/techservicesillinois/WebhookToSplunk
cd WebhookToSplunk
```

### 2. Create a copy of local.settings.template.json as local.settings.json

If you skip this step, the Deploy script will create one for you and you can enter values
interactively during the deployment.

```
cp local.settings.template.json local.settings.json
```

### 3. Populate all required variables in the local.settings.json

> [!IMPORTANT]
> WEBHOOK_SENDER_NAME is the application you are collecting events from, such as 'github.com'
> WEBHOOK_SENDER_SOURCE is the endpoint or resource you are capturing, such as '/techservicesillinois/WebhookToSplunk/settings/hooks'

> [!IMPORTANT]
> "WEBHOOK_SENDER_SOURCETYPE": "json" is sufficient for most applications that send JSON webhook payloads
> however the json sourcetype in splunk will truncate events to 10000 characters, also individual fields
> may be truncated as well if they exceed the limits. In this case consider using a custom sourcetype that
> can accomodate larger event payloads

```diff
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
-    "SPLUNK_HEC_URL": "https://http-inputs-illinois.splunkcloud.com/services/collector",
-    "SPLUNK_HEC_TOKEN": "",
-    "SPLUNK_INDEX": "",
-    "WEBHOOK_SENDER_NAME": "",
-    "WEBHOOK_SENDER_SOURCE": "",
    "WEBHOOK_SENDER_SOURCETYPE": "json"
  }
}
```

### 4. Create an Azure Resource group

See [Microsoft Learn article](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#create-resource-groups) for instructions.

Record your Resource Group name for Step 5.

### 5. Run the deployment script

> [!IMPORTANT]
> This script will require you to log into the Azure CLI tool, make sure to select the same subscription you created your Resource Group with in Step 4.

Windows

```PowerShell
pwsh .\Deploy.ps1 -ResourceGroup YourResourceGroupName
```

> [!NOTE]
> bash Deploy script for Linux/Mac has not been written yet

> [!NOTE]
> Execution of downloaded scripts may be disabled on your machine.

### 5. Integrate into your application

After successful deployment, the **Webhook URL** will be written to a SECRET.txt file. This URL can be used in any application that can send an outbound webhook.

Each run of the Deploy script will also output a log file as well as an AzDeployment.json file to the same directory. AzDeployment.json contains the details about the resources this deployment created in Azure. Re-running the Deploy script with the same Resource Group will not create additional resources in Azure, only replace the existing environment variables for the function app and generate a new Webhook URL secret.

> [!CAUTION]
> Treat your webhook URL like a password, if it becomes public anybody can use it to send Splunk events on your behalf. Do not commit your webhook URL to source control. The default config and logging folder './DEPLOYMENT DETAILS' is not tracked by this repo's .gitignore or .funcignore.
