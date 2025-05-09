$logFile = "C:\LFSL-install.log"
$marker = "$env:ProgramData\LFSL_SetupPhase.txt"
$scriptPath = "C:\LFSLSetup\win-oobe.ps1"
$runOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

function Log-Message {
    param (
        [string]$message,
        [string]$status = "INFO"
    )
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$status] $message"
    Add-Content -Path $logFile -Value $logEntry
}

Log-Message "Starting win-oobe.ps1 script."

if (-Not (Test-Path $marker)) {
    try {
        Log-Message "Starting Phase 1: Rename computer"

        $newName = Read-Host "Enter the new computer name"
        Log-Message "Renaming computer to '$newName'"
        Rename-Computer -NewName $newName -Force
        Log-Message "Computer successfully renamed to '$newName'."

        try {
            Log-Message "Writing Phase 2 marker to $marker"
            Set-Content -Path $marker -Value 'Phase2' -Encoding ascii
            Log-Message "Phase 2 marker written."
        } catch {
            Log-Message "Error during writing marker: $_" "ERROR"
            throw
        }

        try {
            Log-Message "Registering RunOnce key for Phase 2"
            $quotedScriptPath = '"' + $scriptPath + '"'
            $runOnceValue = "powershell.exe -ExecutionPolicy Bypass -File $quotedScriptPath"
            Set-ItemProperty -Path $runOnceKey -Name 'LFSLPhase2' -Value $runOnceValue
            Log-Message "RunOnce entry set for Phase 2."
        } catch {
            Log-Message "Error during setting RunOnce entry: $_" "ERROR"
            throw
        }

        Log-Message "Computer renamed to '$newName'. Phase 1 completed."
        Write-Host "Setup Phase 1 completed. Press any key to reboot and continue setup."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-Host "Rebooting to continue setup..."
        Log-Message "Rebooting to continue Phase 2 setup."
        Restart-Computer
        exit
    } catch {
        Log-Message "Error in Phase 1: $_." "ERROR"
        throw
    }
} else {
    try {
        Log-Message "Starting Phase 2: Join domain"

        try {
            $password = Read-Host "Enter the domain password" -AsSecureString
            Log-Message "Password entered for domain join."
        } catch {
            Log-Message "Error during password entry: $_." "ERROR"
            throw
        }

        try {
            $username = "lfadmin@lfsl.net"
            $domain = "LFSL.local"
            $cred = New-Object System.Management.Automation.PSCredential ($username, $password)
            Log-Message "Joining domain '$domain' with user '$username'"
            Add-Computer -DomainName $domain -Credential $cred -Restart
            Log-Message "Computer successfully joined domain '$domain'."
        } catch {
            Log-Message "Error during domain join: $_" "ERROR"
            throw
        }

        Log-Message "Phase 2 completed."

        try {
            Log-Message "Removing Phase 2 marker file"
            Remove-Item $marker -Force -ErrorAction SilentlyContinue
            Log-Message "Phase 2 marker removed."
        } catch {
            Log-Message "Error during marker removal: $_" "ERROR"
        }

        try {
            Log-Message "Removing RunOnce key for Phase 2"
            Remove-ItemProperty -Path $runOnceKey -Name 'LFSLPhase2' -ErrorAction SilentlyContinue
            Log-Message "RunOnce entry removed."
        } catch {
            Log-Message "Error during RunOnce entry removal: $_" "ERROR"
        }

        try {
            Log-Message "Removing script file at $scriptPath"
            Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
            Log-Message "Script file removed."
        } catch {
            Log-Message "Error during script file removal: $_" "ERROR"
        }

        
        try {
            $adminAccount = "Administrateur"
            Log-Message "Setting password for local user '$adminAccount'"
            Set-LocalUser -Name $adminAccount -Password $password
            Log-Message "Password for local Administrateur account set successfully."
        } catch {
            Log-Message "Error during setting password for Administrateur account: $_" "ERROR"
            throw
        }


        #############################
        ## THIS MUST BE AT THE END ##
        #############################
        try {
            Log-Message "Executing 'gpupdate /force /boot'"
            Start-Process -FilePath "gpupdate" -ArgumentList "/force" -Wait
            Log-Message "Group Policy update completed."
        } catch {
            Log-Message "Error during gpupdate: $_" "ERROR"
            throw
        }

        Log-Message "Cleanup completed."
    } catch {
        Log-Message "Error in Phase 2: $_." "ERROR"
        throw
    }
}
