param(
    [string]$InstallPath = "$env:USERPROFILE\AppData\Local\CAPTURE"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CAPTURE - Local CCTV Incident Extraction" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check Python
Write-Host "[INFO] Checking Python installation..." -ForegroundColor Yellow
$python = python --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Python not found. Please install Python 3.10+" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Found: $python" -ForegroundColor Green

# Create installation directory
Write-Host "[INFO] Creating installation directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
Write-Host "[OK] Directory: $InstallPath" -ForegroundColor Green

# Enable TLS for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Download core files
Write-Host "[INFO] Downloading core files from GitHub..." -ForegroundColor Yellow

$githubRaw = "https://raw.githubusercontent.com/ARIJIT-off/Capture/main"
$files = @{
    "main.ps1" = "main.ps1"
    "process.py" = "process.py"
    "chat.py" = "chat.py"
    "README.md" = "README.md"
    ".gitignore" = ".gitignore"
    "LICENSE" = "LICENSE"
}

$downloadedCount = 0
foreach ($file in $files.Keys) {
    try {
        $url = "$githubRaw/$($files[$file])"
        $outFile = "$InstallPath\$file"
        
        Write-Host "  Downloading $file..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing -ErrorAction Stop
        Write-Host "  [OK] $file" -ForegroundColor Green
        $downloadedCount++
    } catch {
        Write-Host "  [ERROR] Failed to download $file" -ForegroundColor Red
    }
}

if ($downloadedCount -lt 4) {
    Write-Host ""
    Write-Host "[ERROR] Failed to download required files" -ForegroundColor Red
    Write-Host "[TIP] Check your internet connection and try again" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] All files downloaded" -ForegroundColor Green

# Install Python dependencies
Write-Host "[INFO] Installing Python dependencies..." -ForegroundColor Yellow
Write-Host "  This may take 2-5 minutes..." -ForegroundColor Gray

python -m pip install --upgrade pip 2>&1 | Out-Null
python -m pip install opencv-python transformers pillow numpy torch torchvision 2>&1 | Out-Null

Write-Host "[OK] Dependencies installed" -ForegroundColor Green

# Create PowerShell profile entry
Write-Host "[INFO] Setting up CAPTURE command..." -ForegroundColor Yellow

$captureScript = @"
function CAPTURE {
    `$scriptPath = "$InstallPath\main.ps1"
    if (Test-Path `$scriptPath) {
        & powershell -NoExit -File `$scriptPath
    } else {
        Write-Host "[ERROR] CAPTURE files not found" -ForegroundColor Red
    }
}
"@

if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw
    if ($profileContent -notlike "*function CAPTURE*") {
        "`n$captureScript" | Add-Content $PROFILE
        Write-Host "[OK] CAPTURE alias added to profile" -ForegroundColor Green
    }
} else {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    Set-Content $PROFILE $captureScript
    Write-Host "[OK] PowerShell profile created" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[SUCCESS] Installation complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Close PowerShell completely" -ForegroundColor White
Write-Host "  2. Open a NEW PowerShell window" -ForegroundColor White
Write-Host "  3. Type: CAPTURE" -ForegroundColor White
Write-Host ""
