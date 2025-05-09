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
        try {
            $renameCommand = "Rename-Computer -NewName $newName -Force"
            Log-Message "Executing command: $renameCommand"
            Invoke-Expression $renameCommand
            Log-Message "Computer successfully renamed to '$newName'."
        }
        catch {
            Log-Message "Error during Rename-Computer: $_. Command: $renameCommand" "ERROR"
            throw
        }

        # Write marker for Phase 2
        try {
            $markerContent = "Phase2"
            $writeMarkerCommand = "$markerContent | Out-File $marker -Encoding ascii"
            Log-Message "Executing command: $writeMarkerCommand"
            Invoke-Expression $writeMarkerCommand
            Log-Message "Phase 2 marker written."
        }
        catch {
            Log-Message "Error during writing marker: $_. Command: $writeMarkerCommand" "ERROR"
            throw
        }

        # Register script to run again on next login
        try {
            $setRunOnceCommand = "Set-ItemProperty -Path $runOnceKey -Name 'LFSLPhase2' -Value 'powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`"'"
            Log-Message "Executing command: $setRunOnceCommand"
            Invoke-Expression $setRunOnceCommand
            Log-Message "RunOnce entry set for Phase 2."
        }
        catch {
            Log-Message "Error during setting RunOnce entry: $_. Command: $setRunOnceCommand" "ERROR"
            throw
        }

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
        Log-Message "Error in Phase 1: $_." "ERROR"
        throw
    }
}
else {
    try {
        Log-Message "Starting Phase 2: Join domain"

        # Ask user for password
        try {
            $password = Read-Host "Enter the domain password" -AsSecureString
            Log-Message "Password entered for domain join."
        }
        catch {
            Log-Message "Error during password entry: $_." "ERROR"
            throw
        }

        # Build credential and join domain
        try {
            $username = "lfadmin@lfsl.net"
            $domain = "LFSL.local"
            $cred = New-Object System.Management.Automation.PSCredential ($username, $password)

            $addComputerCommand = "Add-Computer -DomainName $domain -Credential $cred -Restart"
            Log-Message "Executing command: $addComputerCommand"
            Invoke-Expression $addComputerCommand
            Log-Message "Computer successfully joined domain '$domain'."
        }
        catch {
            Log-Message "Error during domain join: $_. Command: $addComputerCommand" "ERROR"
            throw
        }

        Log-Message "Phase 2 completed."

        # Cleanup: Remove marker file
        try {
            $removeMarkerCommand = "Remove-Item $marker -Force -ErrorAction SilentlyContinue"
            Log-Message "Executing command: $removeMarkerCommand"
            Invoke-Expression $removeMarkerCommand
            Log-Message "Phase 2 marker removed."
        }
        catch {
            Log-Message "Error during marker removal: $_. Command: $removeMarkerCommand" "ERROR"
        }

        # Cleanup: Remove RunOnce entry
        try {
            $removeRunOnceCommand = "Remove-ItemProperty -Path $runOnceKey -Name 'LFSLPhase2' -ErrorAction SilentlyContinue"
            Log-Message "Executing command: $removeRunOnceCommand"
            Invoke-Expression $removeRunOnceCommand
            Log-Message "RunOnce entry removed."
        }
        catch {
            Log-Message "Error during RunOnce entry removal: $_. Command: $removeRunOnceCommand" "ERROR"
        }

        # Cleanup: Remove script file
        try {
            $removeScriptCommand = "Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue"
            Log-Message "Executing command: $removeScriptCommand"
            Invoke-Expression $removeScriptCommand
            Log-Message "Script file removed."
        }
        catch {
            Log-Message "Error during script file removal: $_. Command: $removeScriptCommand" "ERROR"
        }

        Log-Message "Cleanup completed."
    }
    catch {
        Log-Message "Error in Phase 2: $_." "ERROR"
        throw
    }
}
