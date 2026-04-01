function Invoke-AxcientX360RecoverRestMethod {
    [Cmdletbinding()]
    param(
        [ValidateSet('GET', 'POST', 'HEAD')]
        [string] $Method = 'GET',
        [Parameter(Mandatory = $true)]
        [string] $Endpoint,
        [Parameter(Mandatory = $false)]
        $Body,
        [HashTable] $Parameters,
        [int] $MaxRetries = 3
    )

    Write-Verbose "Axcient x360Recover API Base URL: $($IntegrationContext.ApiBaseUrl)"
    
    [Uri] $Url = "$($IntegrationContext.ApiBaseUrl.ToString().TrimEnd('/'))/$Endpoint"

    if ($Parameters) {
        try {
            if ($Parameters) {
                $Url = AddUriQueryParameter -Uri $Url -Parameter $Parameters
            }
        } catch {
            throw "Failed to construct API URL with query parameters: $($_.Exception.Message)"
        }
    }
    
    $RequestParams = [ordered] @{
        Uri = $Url
        Method = $Method
        ContentType = "application/json"
        Headers = @{
            "X-Api-Key" = "$($IntegrationContext.ApiKey)"
        }
    }
    
    if ($Body) {
        $RequestParams.'Body' = $Body
    }

    $RetryCount = 0

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
                429 {
                    if ($RetryCount -lt $MaxRetries) {
                        Write-Warning "API rate limit reached. Retrying in 60 seconds... (Attempt $($RetryCount + 1)/$MaxRetries)"
                        Start-Sleep -Seconds 60
                        $RetryCount++
                        continue
                    }
                    throw "API rate limit exceeded after $MaxRetries retries: $ExceptionMessage"
                }

                401 {
                    throw "Unauthorized"
                }

                403 {
                    if ($RetryCount -lt $MaxRetries) {
                        Write-Warning "Access forbidden (possible DDOS protection). Retrying in 5 minutes... (Attempt $($RetryCount + 1)/$MaxRetries)"
                        Start-Sleep -Seconds 300
                        $RetryCount++
                        continue
                    }
                    throw "Access forbidden after $MaxRetries retries: $ExceptionMessage"
                }

                404 {
                    throw "Endpoint not found: $Endpoint"
                }

                504 {
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
    [CmdletBinding()]
    param()

    try {
        $Endpoint = "vault/$VaultId"

        $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint

        if ($null -ne $Response.active -and $Response.active -eq $true) {
            return $true
        } else {
            return $false
        }
    } catch {
        return false
    }
}

function Get-AxcientX360RecoverClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int] $ClientId = $null
    )

    try {
        if ($ClientId) {
            $Endpoint = "client/$ClientId"

            $Response =  Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint

            if (-not $Response.id) {
                return $Response
            } else {
                throw "Failed to get client: $ClientId"
            }
        } else {
            $Endpoint = "client"

            $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint 

            if ($Response -is [array]) {
                return $Response
            } else {
                throw "Failed to get clients"
            }
        }
    } catch {
        throw "Failed to execute Get-AxcientX360RecoverClient: $($_.Exception.Message)"
    }
}

function Get-AxcientX360RecoverDevice {
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
            try {
                $Endpoint = "company/$ClientId/device"

                $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint

                if ($Response -is [array]) {
                    return $Response
                } else {
                    throw "Failed to get devices for client: $ClientId"
                }

                return $Response
            } catch {
                throw "Failed to execute Get-AxcientX360RecoverDevice: $($_.Exception.Message)"
            }
        }
        "ByDeviceId" {
            try {
                $Endpoint = "device/$DeviceId"

                $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint

                if (-not $Response.id) {
                    return $Response
                } else {
                    throw "Failed to get device: $DeviceId"
                }
            } catch {
                throw "Failed to execute Get-AxcientX360RecoverDevice: $($_.Exception.Message)"
            }
        }
        "ByPsLocalId" {
            try {
                $Endpoint = "device"

                $Parameters = @{
                        "local_ps_id" = $LocalPsId
                }

                $Response = Invoke-AxcientX360RecoverRestMethod -Method GET -Endpoint $Endpoint -Parameters $Parameters

                if (-not $Response.id) {
                    return $Response
                } else {
                    throw "Failed to get device with Local PS ID: $LocalPsId"
                }
            } catch {
                throw "Failed to execute Get-AxcientX360RecoverDevice: $($_.Exception.Message)"
            }
        }
    }
}

function Get-AxcientX360RecoverAgentToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int] $ClientId
    )

    try {
        $Endpoint = "/client/{$ClientId}/vault/$($IntegrationContext.VaultId)/d2c_agent"

        $Response = Invoke-AxcientX360RecoverRestMethod -Method POST -Endpoint $Endpoint

        if (-not $Response.token_id) {
            return $Response.token_id
        } else {
            throw "Failed to get agent token for client: $ClientId"
        }
    } catch {
        throw "Failed to execute Get-AxcientX360RecoverAgentToken: $($_.Exception.Message)"
    }
}

function Get-AxcientX360RecoverDynamicVersions {
    [CmdletBinding()]
    param()

    Get-DynamicVersionFromInstallerURL "https://updates.axcient.cloud/xcloud-agent/agentInstaller.msi"
}

Export-ModuleMember -Function @(
    'Test-AxcientX360RecoverConnection',
    'Test-AxcientX360RecoverVault',
    'Get-AxcientX360RecoverClient',
    'Get-AxcientX360RecoverDevice',
    'Get-AxcientX360RecoverAgentToken',
    'Get-AxcientX360RecoverDynamicVersions'
)