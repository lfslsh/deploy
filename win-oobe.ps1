# Path to the phase marker file
$marker = "$env:ProgramData\LFSL_SetupPhase.txt"

if (-Not (Test-Path $marker)) {
    # === Phase 1: Rename the computer ===
    $newName = Read-Host "Enter the computer name"
    Rename-Computer -NewName $newName -Force

    # Mark phase completion
    "Phase2" | Out-File $marker -Encoding ASCII

    Restart-Computer
} else {
    # === Phase 2: Join domain ===

    $domain = "LFSL.local"
    $username = "lfadmin@lfsl.net"

    Write-Host "Enter password for $username"
    $secpasswd = Read-Host -AsSecureString

    $cred = New-Object System.Management.Automation.PSCredential($username, $secpasswd)

    # Join domain and restart
    Add-Computer -DomainName $domain -Credential $cred -Restart

    # Clean up
    Remove-Item $marker -Force
    Remove-Item $MyInvocation.MyCommand.Path -Force
}
