## About

Easy to deploy Azure Cloud Function to expose the Splunk HTTP Event Collector (HEC API) as a webhook endpoint for applications that do not have native integration with Splunk. This can be used where it is not possible or unfeasible to directly send events to Splunk, such as 3rd party systems and legacy applications.

This open-source tool is intended to be deployed for any Azure & Splunk Enterprise 6.3.0+ or Splunk Cloud Platform environment, sample data and endpoint declarations are available below for deploying within the UIUC environment.

## Data Sources

For data sensitivity, see [Data Classification](https://www.cybersecurity.illinois.edu/data-classification/). Substitute (Your Application) with the application which will be sending webhook payloads to this application.

| Data Store         | Data Type                 | Sensitivity                       | Notes                                                                                                        |
| ------------------ | ------------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| (Your Application) | (data sent from your app) | (Appropriate Data Classification) | This application will injest data sent to it via webhook. Data is transmitted to on-premise Splunk instance. |

## Endpoint Connections

This application's public endpoint URL is configured during deployment to your own Azure App Service Plan.

| Endpoint                                                        | Purpose                         | Stage | Access               | Contact                                                                                  |
| --------------------------------------------------------------- | ------------------------------- | ----- | -------------------- | ---------------------------------------------------------------------------------------- |
| (Function URL)                                                  | Webhook receiver                | prod  | Inbound HTTPS, POST  | (Your Azure admin)                                                                       |
| https://http-inputs-illinois.splunkcloud.com/services/collector | Splunk HTTP Event Collector API | prod  | Outbound HTTPS, POST | Splunk service team<br>[splunk-support@illinois.edu](mailto:splunk-support@illinois.edu) |

## Product Support

This product is supported by James Harrell ([jharrell@illinois.edu](mailto:jharrell@illinois.edu)) on a best-effort basis.

As of the last update to this README, the expected End-of-Life and
End-of-Support dates of this product are 2028 April.

End-of-Life was decided upon based on these dependencies:

- Node.js 24.16.0 LTS (2028 April 30)
- Azure Cloud Function v4 Runtime (end-of-life TBD)

# Getting Started

## Software Prerequisites

1. Install Node.js v24.16.0 LTS: [download archive](https://nodejs.org/en/download/archive/v24.16.0)
2. Install Azure CLI: [microsoft learn article](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

## Basic Setup

### 1. Clone the repo:

```
git clone https://github.com/techservicesillinois/WebhookToSplunk
cd WebhookToSplunk
```

### 2. Install all dependencies:

```
npm install
```

### 3. Create a copy of .env.template as .env

```
cp .env.template .env
```

### 4. Populate all required variables in the .env

### 5. Run the interactive deployment script

Windows

```PowerShell
pwsh .\Deploy.ps1
```

Mac/Linux

```bash
bash ./Deploy.sh
```

> [!NOTE]
> Execution of downloaded scripts may be disabled on your machine.

### 6. Integrate into your application

After successful deployment of your cloud function, the **webhook URL** will be displayed in your console. This URL can be used in any application that can send an outbound webhook.

> [!CAUTION]
> Treat your webhook URL like a password, if it becomes public anybody can use it to send Splunk events on your behalf. Do not commit your webhook URL to source control.
