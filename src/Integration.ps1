# ============================================================================
# ImmyBot dynamic integration for the Axcient x360Recover backup platform.
#
# Capabilities:
#   - ISupportsListingClients:          Enumerates active, non-parked clients
#   - ISupportsListingAgents:           Lists Windows backup agents per client
#   - ISupportsInventoryIdentification: Identifies agents via local config GUID
#   - ISupportsTenantInstallToken:      Retrieves D2C agent install tokens
#   - ISupportsDynamicVersions:         Resolves latest agent installer version
# ============================================================================

# ---- Integration initialization and credential validation ----
$Integration = New-DynamicIntegration -Init {
    param(
        [Parameter(Mandatory = $true)]
        [DisplayName("API Key")]
        [Password(StripValue = $true)]
        $ApiKey,
        [Parameter(Mandatory = $true)]
        [DisplayName("Vault ID")]
        [int] $VaultId
    )
    Import-Module AxcientX360RecoverAPI

    # Store credentials and configuration in the shared integration context
    $IntegrationContext.ApiKey = $ApiKey
    $IntegrationContext.ApiBaseUrl = "https://axapi.axcient.com/x360recover"
    $IntegrationContext.VaultId = $VaultId

    # Validate API connectivity before accepting the configuration
    if (!(Test-AxcientX360RecoverConnection)) {
        throw "Unable to connect to the Axcient x360Recover API with the supplied API Key."
    }

    # Validate that the vault exists and is active
    if (!(Test-AxcientX360RecoverVault)) {
        throw "The supplied Axcient x360Recover Vault ID is either invalid or inactive."
    }

    $IntegrationContext.LastConnectionTime = Get-Date

    Write-Host "Axcient x360Recover integration initialized successfully"

    [OpResult]::Ok()
# ---- Health check: verifies API connectivity and vault status ----
} -HealthCheck {
    [CmdletBinding()]
    [OutputType([HealthCheckResult])]
    param()

    Import-Module AxcientX360RecoverAPI

    if (!(Test-AxcientX360RecoverConnection)) {
        return New-UnhealthyResult -Message "Unable to connect to the Axcient x360Recover API."
    }

    if (!(Test-AxcientX360RecoverVault)) {
        return New-UnhealthyResult -Message "The configured Axcient x360Recover Vault ID is either invalid or inactive."
    }

    Write-Host "Health check passed. Connected to Axcient x360Recover API at $($IntegrationContext.ApiBaseUrl)"
    Write-Verbose "Last connection: $($IntegrationContext.LastConnectionTime)"

    return New-HealthyResult
}

# ---- ISupportsListingClients: returns active, non-parked clients ----
$Integration | Add-DynamicIntegrationCapability -Interface ISupportsListingClients -GetClients {
    [CmdletBinding()]
    [OutputType([Immybot.Backend.Domain.Providers.IProviderClientDetails[]])]
    param()

    Import-Module AxcientX360RecoverAPI

    $Clients = Get-AxcientX360RecoverClient

    if (($null -ne $Clients) -and ($Clients -is [array])) {
        foreach ($Client in $Clients) {
            # Skip parked or inactive clients — only return actively managed ones
            if (($Client.health_status -notin "PARKED") -and ($Client.active -eq 1)) {
                New-IntegrationClient -ClientId $Client.id -ClientName $Client.name
            }
        }
    } else {
        return $null
    }
}

# ---- ISupportsListingAgents: returns Windows backup agents for given clients ----
$Integration | Add-DynamicIntegrationCapability -Interface ISupportsListingAgents -GetAgents {
    [CmdletBinding()]
    [OutputType([Immybot.Backend.Domain.Providers.IProviderAgentDetails[]])]
    param(
        [Parameter()]
        [string[]] $ClientIds = $null
    )

    Import-Module AxcientX360RecoverAPI

    $ClientIds | ForEach-Object {
        $Devices = Get-AxcientX360RecoverDevice -ClientId $_

        if (($null -ne $Devices) -and ($Devices -is [array])) {
            $Devices | ForEach-Object {
                # Only Windows devices are supported for ImmyBot management
                if ($_.os.os_type -ne "WINDOWS") {
                    continue
                }

                # Extract short hostname (strip domain suffix) and normalize to uppercase
                $Hostname = (($_.name -split '\.')[0]).ToUpper()

                New-IntegrationAgent `
                    -AgentId $_.local_ps_id `
                    -Name $Hostname `
                    -ClientId $_.client_id `
                    -AgentVersion $_.agent_version `
                    -SupportsRunningScripts $false `
                    -OSName $_.os.os_name
            }
        } else {
            continue
        }
    }
}

# ---- ISupportsInventoryIdentification: reads agent GUID from local config ----
# Runs on the target device via Invoke-ImmyCommand to extract the unique agent
# identifier from the Axcient aristos.cfg INI file ([Config] section, GUID key).
$Integration | Add-DynamicIntegrationCapability -Interface ISupportsInventoryIdentification -GetInventoryScript {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    Import-Module AxcientX360RecoverAPI

    Invoke-ImmyCommand {
        $AxcientConfigPath = "C:\Program Files (x86)\Replibit\aristos.cfg"

        if (Test-Path -Path $AxcientConfigPath) {
            # Copy config to temp to avoid file-lock conflicts with the running agent
            Copy-Item -Path $AxcientConfigPath -Destination $env:TEMP -Force

            # Open with read-share to prevent locking issues
            $Stream = [System.IO.File]::Open(
                "$($env:TEMP)\aristos.cfg",
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::Read
            )

            $Reader = [System.IO.StreamReader]::new($Stream)
            $Content = $Reader.ReadToEnd()
            $Reader.Close()
            $Stream.Close()

            # Parse INI-style config to locate GUID under the [Config] section
            $CurrentSection = ""
            $InTargetSection = $false

            foreach ($Line in $Content -split "`r`n|`n") {
                $Line = $Line.Trim()

                # Skip blank lines and comments
                if (($Line -eq "") -or ($Line.StartsWith(";")) -or ($Line.StartsWith("#"))) {
                    continue
                }

                # Detect section headers like [Config]
                if ($Line -match "^\[(.+)\]$") {
                    $CurrentSection = $Matches[1].Trim()
                    $InTargetSection = ($CurrentSection -eq "Config")

                    continue
                }

                # Return the GUID value when found in the [Config] section
                if ($InTargetSection -and ($Line -match "^([^=]+)=(.*)$")) {
                    $ParsedKey = $Matches[1].Trim()
                    $ParsedValue = $Matches[2].Trim()

                    if ($ParsedKey -eq "GUID") {
                        return $ParsedValue
                    }
                }
            } else {
                return $null
            }
        } else {
            return $null
        }
    }
}

# ---- ISupportsTenantInstallToken: retrieves a D2C agent install token ----
$Integration | Add-DynamicIntegrationCapability -Interface ISupportsTenantInstallToken -GetTenantInstallToken {
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ClientId
    )

    Import-Module AxcientX360RecoverAPI

    Get-AxcientX360RecoverAgentToken -ClientId $ClientId
}

# ---- ISupportsDynamicVersions: resolves latest agent installer version ----
$Integration | Add-DynamicIntegrationCapability -Interface ISupportsDynamicVersions -GetDynamicVersions {
    Import-Module AxcientX360RecoverAPI

    Get-AxcientX360RecoverDynamicVersions
}

return $Integration