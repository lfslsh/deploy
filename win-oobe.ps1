# win-oobe.ps1

$marker = "$env:ProgramData\LFSL_SetupPhase.txt"
$scriptPath = "C:\LFSLSetup\win-oobe.ps1"
$runOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

if (-Not (Test-Path $marker)) {
    Write-Host "Starting Phase 1: Rename computer"

    # Ask user for computer name
    $newName = Read-Host "Enter the new computer name"
    Rename-Computer -NewName $newName -Force

    # Write marker for Phase 2
    "Phase2" | Out-File $marker -Encoding ascii

    # Register script to run again on next login
    Set-ItemProperty -Path $runOnceKey -Name "LFSLPhase2" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`""

    Write-Host "Rebooting to continue setup..."
    Restart-Computer
    exit
}
else {
    Write-Host "Starting Phase 2: Join domain"

    # Ask user for password
    $password = Read-Host "Enter the domain password" -AsSecureString

    # Build credential and join domain
    $username = "lfadmin@lfsl.net"
    $domain = "LFSL.local"
    $cred = New-Object System.Management.Automation.PSCredential ($username, $password)

    Add-Computer -DomainName $domain -Credential $cred -Restart

    # Cleanup (if we don’t restart above, add manual restart here)
    Remove-Item $marker -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $runOnceKey -Name "LFSLPhase2" -ErrorAction SilentlyContinue
    Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
}
