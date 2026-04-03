# ============================================================================
# Performs a silent MSI installation of the Axcient x360Recover backup agent.
# Uses ImmyBot's Start-ProcessWithLogTail to stream installer logs in real time.
# ============================================================================

$ArgumentList = @{}

# Retrieve the agent install token provisioned for the current tenant
$AgentInstallToken = Get-IntegrationAgentInstallToken

# Determine backup target: local appliance (SERVER) or direct-to-cloud (TOKENID)
if ($null -ne $ApplianceIPAddress) {
    $ArgumentList += @{SERVER=$ApplianceIPAddress}
} elseif ($null -ne $AgentInstallToken) {
    $ArgumentList += @{TOKENID=$AgentInstallToken}
} else {
    throw "No Appliance IP address or Agent Token found."
}

# Configure system tray icon visibility based on deployment preference
if ($ShowTrayIcon) {
    $ArgumentList += @{ENABLE_SYSTRAY=true}
} else {
    $ArgumentList += @{ENABLE_SYSTRAY=false}
}

# Execute the installer, tailing the log file for output
Install-MSI -Path $InstallerFile -MSIParameters $ArgumentList -Tail

return