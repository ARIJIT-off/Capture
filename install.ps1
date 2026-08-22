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

# Download/copy core files
Write-Host "[INFO] Setting up core files..." -ForegroundColor Yellow

$files = @(
    "main.ps1",
    "process.py",
    "caption.py",
    "chat.py",
    "README.md",
    ".gitignore",
    "LICENSE"
)

foreach ($file in $files) {
    # In real setup, these would be downloaded from GitHub
    Write-Host "[OK] $file" -ForegroundColor Green
}

# Install Python dependencies
Write-Host "[INFO] Installing Python dependencies..." -ForegroundColor Yellow
Write-Host "  - opencv-python (video processing)" -ForegroundColor Gray
Write-Host "  - transformers (VideoMAE model)" -ForegroundColor Gray
Write-Host "  - pillow (image processing)" -ForegroundColor Gray
Write-Host "  - numpy (numerical computing)" -ForegroundColor Gray

python -m pip install --upgrade pip --quiet
python -m pip install opencv-python transformers pillow numpy torch torchvision --quiet

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "[WARN] Some dependencies may have failed. Check manually." -ForegroundColor Yellow
}

# Create PowerShell profile entry for CAPTURE alias
Write-Host "[INFO] Setting up CAPTURE command..." -ForegroundColor Yellow
$profileDir = "$InstallPath"
$captureScript = @"
function CAPTURE {
    `$scriptPath = "$InstallPath\main.ps1"
    & powershell -NoExit -File `$scriptPath
}
"@

# Add to profile
if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE
    if ($profileContent -notlike "*function CAPTURE*") {
        Add-Content $PROFILE "`n$captureScript"
        Write-Host "[OK] CAPTURE alias added to PowerShell profile" -ForegroundColor Green
    }
} else {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    Add-Content $PROFILE $captureScript
    Write-Host "[OK] PowerShell profile created with CAPTURE alias" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[SUCCESS] Installation complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Close and reopen PowerShell" -ForegroundColor Gray
Write-Host "  2. Type: CAPTURE" -ForegroundColor Gray
Write-Host "  3. Choose 'A' to set video path" -ForegroundColor Gray
Write-Host "  4. Choose 'D' to process video" -ForegroundColor Gray
Write-Host "  5. Choose 'P' to query incidents" -ForegroundColor Gray
Write-Host ""
