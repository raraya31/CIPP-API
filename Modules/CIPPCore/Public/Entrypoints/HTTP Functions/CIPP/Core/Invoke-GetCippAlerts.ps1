using namespace System.Net

function Invoke-GetCippAlerts {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        CIPP.Core.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    Write-LogMessage -headers $Headers -API $APIName -message 'Accessed this API' -Sev 'Debug'

    $Alerts = [System.Collections.Generic.List[object]]::new()
    $Table = Get-CippTable -tablename CippAlerts
    $PartitionKey = Get-Date -UFormat '%Y%m%d'
    $Filter = "PartitionKey eq '{0}'" -f $PartitionKey
    $Rows = Get-CIPPAzDataTableEntity @Table -Filter $Filter | Sort-Object TableTimestamp -Descending | Select-Object -First 10
    $Role = Get-CippAccessRole -Request $Request

    $CIPPVersion = $Request.Query.localversion
    $Version = Assert-CippVersion -CIPPVersion $CIPPVersion
    if ($Version.OutOfDateCIPP) {
        $Alerts.Add(@{
                title = 'CIPP Frontend Out of Date'
                Alert = 'Your CIPP Frontend is out of date. Please update to the latest version. Find more on the following '
                link  = 'https://docs.cipp.app/setup/self-hosting-guide/updating'
                type  = 'warning'
            })
        Write-LogMessage -message 'Your CIPP Frontend is out of date. Please update to the latest version' -API 'Updates' -tenant 'All Tenants' -sev Alert

    }
    if ($Version.OutOfDateCIPPAPI) {
        $Alerts.Add(@{
                title = 'CIPP API Out of Date'
                Alert = 'Your CIPP API is out of date. Please update to the latest version. Find more on the following'
                link  = 'https://docs.cipp.app/setup/self-hosting-guide/updating'
                type  = 'warning'
            })
        Write-LogMessage -message 'Your CIPP API is out of date. Please update to the latest version' -API 'Updates' -tenant 'All Tenants' -sev Alert
    }

    if ($env:ApplicationID -eq 'LongApplicationID' -or $null -eq $env:ApplicationID) {
        $Alerts.Add(@{
                title          = 'SAM Setup Incomplete'
                Alert          = 'You have not yet completed your setup. Please go to the Setup Wizard in Application Settings to connect CIPP to your tenants.'
                link           = '/cipp/setup'
                type           = 'warning'
                setupCompleted = $false
            })
    }
    if ($role -like '*superadmin*') {
        $Alerts.Add(@{
                title = 'Superadmin Account Warning'
                Alert = 'You are logged in under a superadmin account. This account should not be used for normal usage.'
                link  = 'https://docs.cipp.app/setup/installation/owntenant'
                type  = 'error'
            })
    }
    if ((!$env:WEBSITE_RUN_FROM_PACKAGE -or [string]::IsNullOrEmpty($env:WEBSITE_RUN_FROM_PACKAGE)) -and $env:AzureWebJobsStorage -ne 'UseDevelopmentStorage=true') {
        $Alerts.Add(
            @{
                title = 'Function App in Write Mode'
                Alert = 'Your Function App is running in write mode. This will cause performance issues and increase cost. Please check this '
                link  = 'https://docs.cipp.app/setup/installation/runfrompackage'
                type  = 'warning'
            })
    }
    if ($Rows) { $Rows | ForEach-Object { $Alerts.Add($_) } }
    $Alerts = @($Alerts)

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Alerts
        })

}
