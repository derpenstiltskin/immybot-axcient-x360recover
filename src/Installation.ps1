# ============================================================================
# Performs a silent MSI installation of the Axcient x360Recover backup agent.
# Uses ImmyBot's Start-ProcessWithLogTail to stream installer logs in real time.
# ============================================================================

# Retrieve the agent install token provisioned for the current tenant
$AgentInstallToken = Get-IntegrationAgentInstallToken

# Determine backup target: local appliance (SERVER) or direct-to-cloud (TOKENID)
$BackupType = $ApplianceIPAddress ? "SERVER=$ApplianceIPAddress" : "TOKENID=$AgentInstallToken"

# Configure system tray icon visibility based on deployment preference
$TrayIcon = $ShowTrayIcon ? "ENABLE_SYSTRAY=true" : "ENABLE_SYSTRAY=false"

# Build MSI arguments: silent install, verbose logging, suppress reboot
$ArgumentList = " /qn /l*v '$InstallerLogFile' REBOOT=REALLYSUPPRESS /norestart $BackupType $TrayIcon"

# Execute the installer with a 15-minute timeout, tailing the log file for output
Start-ProcessWithLogTail -Path $InstallerFile -LogFilePath $InstallerLogFile -TimeoutSeconds 900 -ArgumentList $ArgumentList

return