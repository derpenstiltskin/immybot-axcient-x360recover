# ============================================================================
# AxcientX360RecoverAPI — PowerShell module providing wrapper functions for
# the Axcient x360Recover REST API. Used by the ImmyBot dynamic integration.
# ============================================================================

function Invoke-AxcientX360RecoverRestMethod {
    <#
    .SYNOPSIS
        Sends an authenticated request to the Axcient x360Recover API.
    .DESCRIPTION
        Constructs and executes REST API calls against the x360Recover API using
        credentials stored in $IntegrationContext. Includes automatic retry logic
        for rate-limiting (429), forbidden (403), and gateway timeout (504) responses.
    .PARAMETER Method
        HTTP method to use. Defaults to GET.
    .PARAMETER Endpoint
        API endpoint path (appended to the base URL). Example: "client" or "device/123".
    .PARAMETER Body
        Request body for POST requests. Ignored for other methods.
    .PARAMETER QueryParams
        Hashtable of query string parameters for GET requests.
    .PARAMETER MaxRetries
        Maximum number of retry attempts for retryable errors. Defaults to 3.
    .OUTPUTS
        The deserialized API response object.
    #>
    [Cmdletbinding()]
    param(
        [ValidateSet("GET", "POST", "HEAD")]
        [string] $Method = "GET",
        [Parameter(Mandatory = $true)]
        [string] $Endpoint,
        [Parameter(Mandatory = $false)]
        $Body,
        [Parameter(Mandatory = $false)]
        [HashTable] $QueryParams = @{},
        [Parameter(Mandatory = $false)]
        [int] $MaxRetries = 3
    )

    Write-Verbose "Axcient x360Recover API Base URL: $($IntegrationContext.ApiBaseUrl)"

    # Build the full URL by appending the endpoint to the base URL
    [Uri] $Url = "$($IntegrationContext.ApiBaseUrl.ToString().TrimEnd('/'))/x360recover/$Endpoint"

    $RequestParams = [ordered] @{
        Uri = $Url
        Method = $Method
        ContentType = "application/json"
        Headers = @{
            "X-Api-Key" = "$($IntegrationContext.ApiKey)"
        }
    }

    # Attach query parameters for GET requests
    if (($Method -eq "GET") -and ($QueryParams.Count -gt 0)) {
        $RequestParams["Body"] = $QueryParams
    }

    # Attach body payload for POST requests
    if (($Method -eq "POST") -and ($null -ne $Body)) {
        $RequestParams["Body"] = $Body
    }

    $RetryCount = 0

    # Retry loop for transient API errors
    do {
        try {
            return Invoke-RestMethod @RequestParams
        } catch {
            $StatusCode = $null

            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $StatusCode = [int] $_.Exception.Response.StatusCode
            }

            $ExceptionMessage = $_.Exception.Message

            switch ($StatusCode) {
                429 { # Rate limited — exponential backoff
                    if ($RetryCount -lt $MaxRetries) {
                        $WaitTime = [Math]::Pow(4, $RetryCount)
                        Write-Warning "API rate limit reached. Retrying in $WaitTime seconds... (Attempt $($RetryCount + 1)/$MaxRetries)"
                        Start-Sleep -Seconds $WaitTime
                        $RetryCount++
                        continue
                    }
                    throw "API rate limit exceeded after $MaxRetries retries: $ExceptionMessage"
                }

                401 { # Invalid or expired API key
                    throw "Unauthorized"
                }

                403 { # Possible DDOS protection — wait 5m before retry
                    if ($RetryCount -lt $MaxRetries) {
                        Write-Warning "Access forbidden (possible DDOS protection). Retrying in 5 minutes... (Attempt $($RetryCount + 1)/$MaxRetries)"
                        Start-Sleep -Seconds 300
                        $RetryCount++
                        continue
                    }
                    throw "Access forbidden after $MaxRetries retries: $ExceptionMessage"
                }

                404 { # Endpoint does not exist
                    throw "Endpoint not found: $Endpoint"
                }

                504 { # Gateway timeout — wait 60s before retry
                    if ($RetryCount -lt $MaxRetries) {
                        Write-Warning "Gateway timeout. Retrying in 60 seconds... (Attempt $($retryCount + 1)/$MaxRetries)"
                        Start-Sleep -Seconds 60
                        $RetryCount++
                        continue
                    }

                    throw "Gateway timeout after $MaxRetries retries: $ExceptionMessage"
                }

                default {
                    throw "API request failed with status $StatusCode : $ExceptionMessage"
                }
            }
        }
    } while ($RetryCount -lt $MaxRetries)
}

function Test-AxcientX360RecoverConnection {
    <#
    .SYNOPSIS
        Tests connectivity to the Axcient x360Recover API.
    .DESCRIPTION
        Sends a lightweight HEAD request to the organization endpoint to verify
        that the API key is valid and the service is reachable.
    .OUTPUTS
        [bool] $true if the connection succeeds.
    #>
    [CmdletBinding()]
    param()

    try {
        Invoke-AxcientX360RecoverRestMethod -Method HEAD -Endpoint "organization" | Out-Null

        return $true
    } catch {
        throw "$($_.Exception.Message)"
        return $false
    }
}

function Test-AxcientX360RecoverVault {
    <#
    .SYNOPSIS
        Validates that the configured vault is active.
    .DESCRIPTION
        Queries the vault endpoint using the VaultId from $IntegrationContext and
        checks that its active flag is set to $true.
    .OUTPUTS
        [bool] $true if the vault exists and is active; $false otherwise.
    #>
    [CmdletBinding()]
    param()

    $Endpoint = "vault/$VaultId"

    $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint

    if (($null -ne $Response.active) -and ($Response.active -eq $true)) {
        return $true
    } else {
        return $false
    }
}

function Get-AxcientX360RecoverClient {
    <#
    .SYNOPSIS
        Retrieves one or all Axcient x360Recover clients.
    .DESCRIPTION
        When a ClientId is provided, returns a single client object. Otherwise,
        returns all clients as an array. Writes an error if the API response is
        empty or unexpected.
    .PARAMETER ClientId
        Optional client ID. If omitted, all clients are returned.
    .OUTPUTS
        A single client object or an array of client objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Nullable[int]] $ClientId = $null
    )

    if ($null -ne $ClientId) {
        $Endpoint = "client/$ClientId"

        $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint

        if ($null -ne $Response.id) {
            return $Response
        } {
            Write-Error "Failed to get Axcient x360Recover Client: $ClientId"
            return $null
        }
    } else {
        $Endpoint = "client"

        $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint

        if (($null -ne $Response) -and ($Response -is [array])) {
            return $Response
        } else {
            Write-Error "Failed to list Axcient x360Recover Clients."
            return $null
        }
    }
}

function Get-AxcientX360RecoverDevice {
    <#
    .SYNOPSIS
        Retrieves Axcient x360Recover devices by client, device ID, or local PS ID.
    .DESCRIPTION
        Supports three lookup modes via parameter sets:
          - ByClientId:  Returns all devices belonging to a client.
          - ByDeviceId:  Returns a single device by its unique device ID.
          - ByLocalPsId: Searches for a device by its local_ps_id (agent GUID).
    .PARAMETER ClientId
        The client ID whose devices should be listed.
    .PARAMETER DeviceId
        The unique device ID to retrieve.
    .PARAMETER LocalPsId
        The local_ps_id (agent GUID) used to identify a specific device.
    .OUTPUTS
        A single device object or an array of device objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "ByClientId")]
        [int] $ClientId,
        [Parameter(Mandatory = $true, ParameterSetName = "ByDeviceId")]
        [int] $DeviceId,
        [Parameter(Mandatory = $true, ParameterSetName = "ByLocalPsId")]
        [string] $LocalPsId
    )

    switch ($PSCmdlet.ParameterSetName) {
        "ByClientId" {
            $Endpoint = "client/$ClientId/device"

            $Limit = 500
            $Offset = 0
            $Devices = @()

            do {
                $QueryParams = @{
                    Limit = $Limit
                    $Offset = $Offset
                }

                $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint -QueryParams $QueryParams

                if (($null -ne $Response) -and ($Response -is [array])) {
                    $Devices += $Response # Sorry Kelvin, Immy made me do it :(

                    $Offset += $Limit
                } else {
                    Write-Error "Failed to list Axcient x360Recover Client Devices: $ClientId"
                    return $null
                }
            } while ($Response.Count -eq $Limit)

            return $Devices
        }
        "ByDeviceId" {
            $Endpoint = "device/$DeviceId"

            $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint

            if ($null -ne $Response.id) {
                return $Response
            } else {
                Write-Error "Failed to get Axcient x360Recover Device: $DeviceId"
            }
        }
        "ByLocalPsId" {
            $Endpoint = "device"

            $QueryParams = @{
                "local_ps_id" = $LocalPsId
            }

            $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint -QueryParams $QueryParams

            if (($null -ne $Response) -and ($Response -is [array]) -and ($Response.Count -gt 0)) {
                return $Response[0]
            } else {
                Write-Error "Failed to get Axcient x360Recover Device by Local_Ps_Id: $LocalPsId"
                return $null
            }
        }
    }
}

function Get-AxcientX360RecoverAgentToken {
    <#
    .SYNOPSIS
        Provisions a direct-to-cloud (D2C) agent install token for a client.
    .DESCRIPTION
        Calls the D2C agent endpoint to generate a one-time install token used
        during agent deployment. The token ties the agent to the specified client
        and the vault configured in $IntegrationContext.
    .PARAMETER ClientId
        The client ID to provision the install token for.
    .OUTPUTS
        [string] The token_id used for agent installation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int] $ClientId
    )

    $Endpoint = "client/$ClientId/vault/$($IntegrationContext.VaultId)/d2c_agent"

    $Response = Invoke-AxcientX360RecoverRestMethod -Method POST -Endpoint $Endpoint

    if ($null -ne $Response.token_id) {
        return $Response.token_id
    } else {
        Write-Error "Failed to get Axcient x360Recover Device Token for Client: $ClientId"
    }
}

function Get-AxcientX360RecoverDynamicVersions {
    <#
    .SYNOPSIS
        Resolves the latest available Axcient agent installer version.
    .DESCRIPTION
        Uses ImmyBot's Get-DynamicVersionFromInstallerURL to inspect the MSI
        download URL and extract version metadata.
    .OUTPUTS
        Dynamic version information derived from the installer URL.
    #>
    [CmdletBinding()]
    param()

    $DynamicVersion = Get-DynamicVersionFromInstallerURL -URL "https://updates.axcient.cloud/xcloud-agent/agentInstaller.msi"

    return $DynamicVersion.Versions
}

Export-ModuleMember -Function @(
    'Test-AxcientX360RecoverConnection',
    'Test-AxcientX360RecoverVault',
    'Get-AxcientX360RecoverClient',
    'Get-AxcientX360RecoverDevice',
    'Get-AxcientX360RecoverAgentToken',
    'Get-AxcientX360RecoverDynamicVersions'
)