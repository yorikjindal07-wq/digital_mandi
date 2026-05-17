param(
    [switch]$RecreateVenv,
    [switch]$RunTests = $true
)

$ErrorActionPreference = "Stop"

function Get-PythonLauncherVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $previousNativeErrorPreference = $null
    $nativePreferenceAvailable = $false

    if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
        $nativePreferenceAvailable = $true
        $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $result = & py "-$Version" -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            return $Version
        }
    } catch {
        return $null
    } finally {
        if ($nativePreferenceAvailable) {
            $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
        }
    }

    return $null
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$pythonVersion = Get-PythonLauncherVersion -Version "3.11"
if (-not $pythonVersion) {
    $pythonVersion = Get-PythonLauncherVersion -Version "3.10"
}

if (-not $pythonVersion) {
    throw "Python 3.10+ is required. Install Python 3.10 or 3.11, then rerun this script."
}

Write-Host "Using Python $pythonVersion for the backend virtual environment..."

if ($RecreateVenv -and (Test-Path ".venv")) {
    Write-Host "Removing existing .venv..."
    Remove-Item -Recurse -Force ".venv"
}

if (-not (Test-Path ".venv")) {
    Write-Host "Creating .venv..."
    & py "-$pythonVersion" -m venv .venv
}

$pythonExe = Join-Path $repoRoot ".venv\Scripts\python.exe"

Write-Host "Upgrading pip..."
& $pythonExe -m pip install --upgrade pip

Write-Host "Installing backend dependencies..."
& $pythonExe -m pip install -r requirements.txt

if ($RunTests) {
    Write-Host "Running backend tests..."
    & $pythonExe -m unittest discover -s tests -v
}

Write-Host "Backend local setup is complete."
