$AgentInstallToken = Get-IntegrationAgentInstallToken

$BackupType = $ApplianceIPAddress ? "SERVER=$ApplianceIPAddress" : "TOKENID=$AgentInstallToken"
$TrayIcon = $ShowTrayIcon ? "ENABLE_SYSTRAY=true" : "ENABLE_SYSTRAY=false"

$ArgumentList = " /qn /l*v '$InstallerLogFile' REBOOT=REALLYSUPPRESS /norestart $BackupType $TrayIcon"

Write-Host "ArgumentList: $ArgumentList"

Start-ProcessWithLogTail -Path $InstallerFile -LogFilePath $InstallerLogFile -TimeoutSeconds 900 -ArgumentList $ArgumentList

return