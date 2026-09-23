$ErrorActionPreference = "Stop"

# Configuration
$ServiceName = "Velociraptor"
$WorkDir = "C:\Velociraptor-lab\automation"

$LogPath = Join-Path $WorkDir "windows-install.log"
$MsiPath = Join-Path $WorkDir "msi-install.log"

$Changes = 0

# Create working directory
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

# Logging function
function Write-Log {
    param(
        [string]$Message
    )

    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"

    Write-Output $Line

    Add-Content -LiteralPath $LogPath -Value $Line
}

Write-Log "Starting Velociraptor installation check"

# Check whether Velociraptor is installed
$Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($null -eq $Service) {
    Write-Log "Velociraptor is not installed"
    # Find the installation package
    $Msi = Get-ChildItem `
        -Path "$env:USERPROFILE\Downloads" `
        -Filter "*velociraptor*windows-amd64.msi"
        -File |
        Select-Object -First 1
    
    if ($null -eq $Msi) {
        throw "Velociraptor package is not found"
    }
    Write-Log "Installing Velociraptor from $($Msi.FullName)"
    $Arguments = '/i "{0}" /qn /norestart /L*v "{1}"' -f `
        $Msi.FullName, $MsiLog

    $Process = Start-Process `
        -FilePath "msiexec.exe" `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru

    if ($Process.ExitCode -notin @(0, 3010)) {
        throw "MSI installation failed: $(Process.ExitCode)"
    }

    $Changes++

    Write-Log "Velociraptor installation completed"
} else {
    Write-Log "Velociraptor is already  installed. Skipping installation"
}

# Verify the service
$Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($null -eq $Service) {
    throw "Velociraptor service not found"
}

$ServiceInfo = Get-CimInstance Win32_Service `
    -Filter "Name='Velociraptor'"

if ($ServiceInfo.StartMode -ne "Auto") {
    Set-Service -Name $ServiceName -StartupType Automatic
    $Changes++
    Write-Log "Service startup changes to Automatic"
} else {
    Write-Log "Service startup is already Automatic"
}

$Service = Get-Service -Name $ServiceName
if ($Service.Status -ne "Running") {
    Start-Service -Name $ServiceName
    $Changes++
    Write-Log "Velociraptor service started"
} else {
    Write-Log "Velociraptor service is already running"
}
$Service = Get-Service -Name $ServiceName
if ($Service.Status -ne "Running") {
    throw "Velociraptor service is not running"
}
Write-Log "RESULT: changed=$Changes; service=$($Service.Status)"