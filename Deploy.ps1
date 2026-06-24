<#
.SYNOPSIS
    Deploy the WebhookToSplunk app using Azure Bicep for infrastructure provisioning.

.DESCRIPTION
    Deploys all Azure infrastructure via azresources.bicep, then builds and
    publishes the Function App code. Splunk settings are read from local.settings.json.
    Webhook URL secret and HEC token are stored in Key Vault; re-deploying will rotate them
    unless you pass -PreserveWebhookSecrets.

.PARAMETER ResourceGroup
    string (required) - Resource group to deploy into (must already exist).

.PARAMETER Location
    string (default 'northcentralus') - Azure region for all resources.

.PARAMETER ConfigPath
    string (default .\DEPLOYMENT_DETAILS\) - path to write log files.

.PARAMETER PreserveWebhookSecrets
    switch - if set, reads existing WebhookUrl from Key Vault before deploying
    so that existing webhook URLs are not invalidated.

.EXAMPLE
    .\Deploy.ps1 -ResourceGroup "netid-w2s"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $False)]
    [string]$Location = 'northcentralus',

    [Parameter(Mandatory = $False)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$ConfigPath = "$PSScriptRoot\DEPLOYMENT_DETAILS",

    [Parameter(Mandatory = $False)]
    [switch]$PreserveWebhookSecrets = $False
)

Begin {
    $LogPath = Join-Path -Path $ConfigPath -ChildPath "Deployment-$(Get-Date -Format FileDateTimeUniversal).log"
    Write-Host "Initializing log file at $LogPath"
    Try {
        Start-Transcript -Path $LogPath -NoClobber -UseMinimalHeader -ErrorAction Stop
        Write-Host "Beginning WebhookToSplunk deployment"
    }
    Catch {
        Write-Error "Cannot write to specified ConfigPath: $ConfigPath`nExiting"
        throw $_
    }

    $null = az account show 2>$null
    If ($LASTEXITCODE -ne 0) {
        Write-Host "Not logged into Azure CLI — launching login"
        az login
        If ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to log into Azure"
            Stop-Transcript
            throw "az login failed"
        }
    }
    $SubscriptionId = az account show --query id -o tsv
    Write-Host "Using subscription: $SubscriptionId"
}

Process {
    # Step 1 — Read Splunk settings from local.settings.json
    $localCfgPath = Join-Path -Path $PSScriptRoot -ChildPath "local.settings.json"
    $cfgTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath "local.settings.template.json"

    If (-not (Test-Path -Path $localCfgPath -PathType Leaf)) {
        Write-Host "Creating new local.settings.json from template"
        Copy-Item -Path $cfgTemplatePath -Destination $localCfgPath
    }

    $cfg = Get-Content -Path $localCfgPath | ConvertFrom-Json -AsHashtable
    $cfgValues = $cfg['Values']
    $cfgTemplateValues = (Get-Content -Path $cfgTemplatePath | ConvertFrom-Json -AsHashtable)['Values']

    $requiredKeys = $cfgTemplateValues.Keys
    $nonCustomKeys = @('AzureWebJobsStorage', 'FUNCTIONS_WORKER_RUNTIME')
    ForEach ($key in $requiredKeys) {
        If ($cfgValues.Keys -notcontains $key -or $cfgValues[$key] -like "") {
            If ($nonCustomKeys -contains $key) {
                # skip prompt for these and just use default value
                $cfgValues[$key] = $cfgTemplateValues[$key]
            }
            Else {
                Write-Error "local.settings.json is missing $key"
                [string]$newVal = Read-Host -Prompt "Enter a value for $key"
                $cfgValues[$key] = $newVal
            }
        }
        Else {
            If ($key -eq 'SPLUNK_HEC_TOKEN') {
                # don't leak hec token in transcript
                Write-Host "✅ SPLUNK_HEC_TOKEN = [redacted]"
            }
            Else {
                Write-Host "✅ $key = $($cfgValues[$key])"
            }
        }
    }
    Set-Content -Path $localCfgPath -Value ($cfg | ConvertTo-Json -Depth 5)
    Write-Host "Validated local.settings.json"

    # Step 2 — Determine webhook URL secret (generated locally so Key Vault read is not required)
    $webhookParams = @{}
    If ($PreserveWebhookSecrets) {
        Write-Host "Attempting to read existing webhook secret from Key Vault..."
        Try {
            $kvList = az keyvault list --resource-group $ResourceGroup --query "[].name" -o tsv
            $kvName = $kvList | Select-Object -First 1
            If ($kvName) {
                $existingSecret = az keyvault secret show --vault-name $kvName --name "WebhookUrl" --query "value" -o tsv 2>$null
                If ($existingSecret) {
                    $webhookParams['webhookUrlSecret'] = $existingSecret
                    Write-Host "✅ Found existing webhook secret — it will be preserved"
                }
                Else {
                    Write-Warning "Could not read existing webhook secret from Key Vault; a new one will be generated"
                }
            }
        }
        Catch {
            Write-Warning "Could not read existing webhook secrets; a new one will be generated"
        }
    }
    If (-not $webhookParams['webhookUrlSecret']) {
        $webhookParams['webhookUrlSecret'] = [System.Guid]::NewGuid().ToString()
        Write-Host "Generated new webhook URL secret locally"
    }
    # Keep a reference so the End block can use it without reading from Key Vault
    $webhookUrlSecret = $webhookParams['webhookUrlSecret']

    # Step 3 — Deploy infrastructure via Bicep
    Try {
        # check ResourceGroup is valid in this subscription
        $rgInfo = (az group show --name $ResourceGroup) | ConvertFrom-Json
        If ($rgInfo) {
            Write-Host "✅ Found resource group $ResourceGroup"
        }
        Else {
            throw "Resource group $ResourceGroup does not exist on $SubscriptionId"
        }
    }
    Catch {
        Stop-Transcript
        throw $_
    }
    Write-Host "Deploying infrastructure via azresources.bicep..."
    $bicepPath = Join-Path -Path $PSScriptRoot -ChildPath "azresources.bicep"

    $deployParams = @(
        "--resource-group", $ResourceGroup,
        "--template-file", $bicepPath,
        "--parameters",
        "location=$Location"
    )
    Foreach ($key in ($cfgValues.Keys | Where-Object -FilterScript { $nonCustomKeys -notcontains $_ })) {
        $deployParams += "$key=$($cfgValues[$key])"
    }
    If ($webhookParams['webhookUrlSecret']) {
        $deployParams += "webhookUrlSecret=$($webhookParams['webhookUrlSecret'])"
    }

    # deployment
    $deployJson = az deployment group create @deployParams --query "properties.outputs" -o json
    If ($LASTEXITCODE -ne 0) {
        Write-Error "Bicep deployment failed (exit code $LASTEXITCODE)"
        Stop-Transcript
        throw "az deployment group create failed"
    }
    $deployOutput = $deployJson | ConvertFrom-Json

    $functionAppName = $deployOutput.functionAppName.value
    $kvName = $deployOutput.keyVaultName.value
    $hostName = $deployOutput.functionAppHostName.value
    Write-Host "✅ Infrastructure deployed — Function App: $functionAppName, Key Vault: $kvName, Host Name: $hostName"
    $deployOutputPath = Join-Path -Path $ConfigPath -ChildPath "AzDeployment.json"
    $deployOutput | ConvertTo-Json -Depth 10 | Set-Content -Path $deployOutputPath
    Write-Host "Deployment details saved to $deployOutputPath"

    # Step 4 — Build TypeScript and publish the function code
    Write-Host "Building TypeScript..."
    Try {
        Push-Location $PSScriptRoot
        npm run build --silent
        Write-Host "Publishing function app code..."
        func azure functionapp publish $functionAppName --subscription $SubscriptionId
        Pop-Location
    }
    Catch {
        Pop-Location
        Write-Error "Failed to build or publish function app"
        Stop-Transcript
        throw $_
    }
    Write-Host "✅ Function code deployed"
}

End {
    Write-Host ""
    Write-Host "🎉 Deployment successful!"
    Write-Host "Your webhook endpoint is: https://$hostName/api/webhook?key={secret}"
    Write-Host "Webhook secret is stored in Key Vault '$kvName'."
    Write-Host ""
    Write-Host "ending transcript"
    Stop-Transcript

    Write-Warning "Treat your webhook URL like an API key. Do not share it."
    $webhookURL = "https://$hostName/api/webhook?key=$webhookUrlSecret"
    $secretPath = Join-Path -Path $ConfigPath -ChildPath "SECRET.txt"
    Set-Content -Path $secretPath -Value $webhookURL
    Write-Host "Webhook URL with secret has been written to $secretPath"
}
