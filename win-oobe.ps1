# win-oobe.ps1

$logFile = "C:\LFSL-install.log"
$marker = "$env:ProgramData\LFSL_SetupPhase.txt"
$scriptPath = "C:\LFSLSetup\win-oobe.ps1"
$runOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

# Function to log messages
function Log-Message {
    param (
        [string]$message,
        [string]$status = "INFO"
    )
    $logEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [$status] $message"
    Add-Content -Path $logFile -Value $logEntry
}

# Log script start
Log-Message "Starting win-oobe.ps1 script."

if (-Not (Test-Path $marker)) {
    try {
        Log-Message "Starting Phase 1: Rename computer"

        # Ask user for computer name
        $newName = Read-Host "Enter the new computer name"
        $renameCommand = "Rename-Computer -NewName $newName -Force"
        Log-Message "Executing command: $renameCommand"
        Invoke-Expression $renameCommand

        # Write marker for Phase 2
        $markerContent = "Phase2"
        $writeMarkerCommand = "$markerContent | Out-File $marker -Encoding ascii"
        Log-Message "Executing command: $writeMarkerCommand"
        Invoke-Expression $writeMarkerCommand

        # Register script to run again on next login
        $setRunOnceCommand = "Set-ItemProperty -Path $runOnceKey -Name 'LFSLPhase2' -Value 'powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`"'"
        Log-Message "Executing command: $setRunOnceCommand"
        Invoke-Expression $setRunOnceCommand

        Log-Message "Computer renamed to '$newName'. Phase 1 completed."

        # Wait for the user to press any key before rebooting
        Write-Host "Setup Phase 1 completed. Press any key to reboot and continue setup."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        Write-Host "Rebooting to continue setup..."
        Log-Message "Rebooting to continue Phase 2 setup."

        # Restart the computer
        Restart-Computer
        exit
    }
    catch {
        Log-Message "Error in Phase 1: $_. Command: $renameCommand" "ERROR"
        throw
    }
}
else {
    try {
        Log-Message "Starting Phase 2: Join domain"

        # Ask user for password
        $password = Read-Host "Enter the domain password" -AsSecureString

        # Build credential and join domain
        $username = "lfadmin@lfsl.net"
        $domain = "LFSL.local"
        $cred = New-Object System.Management.Automation.PSCredential ($username, $password)

        $addComputerCommand = "Add-Computer -DomainName $domain -Credential $cred -Restart"
        Log-Message "Executing command: $addComputerCommand"
        Invoke-Expression $addComputerCommand

        Log-Message "Computer successfully joined domain '$domain'. Phase 2 completed."

        # Cleanup
        $removeMarkerCommand = "Remove-Item $marker -Force -ErrorAction SilentlyContinue"
        Log-Message "Executing command: $removeMarkerCommand"
        Invoke-Expression $removeMarkerCommand

        $removeRunOnceCommand = "Remove-ItemProperty -Path $runOnceKey -Name 'LFSLPhase2' -ErrorAction SilentlyContinue"
        Log-Message "Executing command: $removeRunOnceCommand"
        Invoke-Expression $removeRunOnceCommand

        $removeScriptCommand = "Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue"
        Log-Message "Executing command: $removeScriptCommand"
        Invoke-Expression $removeScriptCommand

        Log-Message "Cleanup completed."
    }
    catch {
        Log-Message "Error in Phase 2: $_. Command: $addComputerCommand" "ERROR"
        throw
    }
}
