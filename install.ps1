# CAPTURE Installation Script
# Run as Administrator

Write-Host "================================" -ForegroundColor Cyan
Write-Host "CAPTURE - Offline CCTV Analysis" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check admin rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Please run as Administrator" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "[1/5] Checking Python..." -ForegroundColor Yellow
$pythonCheck = python --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Python not installed. Install from python.org" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}
Write-Host "✓ Python found: $pythonCheck" -ForegroundColor Green

Write-Host "[2/5] Checking FFmpeg..." -ForegroundColor Yellow
$ffmpegCheck = ffmpeg -version 2>&1 | Select-Object -First 1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: FFmpeg not installed. Download from ffmpeg.org" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}
Write-Host "✓ FFmpeg found" -ForegroundColor Green

Write-Host "[3/5] Installing Python dependencies..." -ForegroundColor Yellow
pip install opencv-python ollama pillow numpy --quiet --break-system-packages
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Some dependencies failed. Continue anyway? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne "Y") { exit }
}
Write-Host "✓ Dependencies installed" -ForegroundColor Green

Write-Host "[4/5] Downloading Ollama models (this may take 10-15 min)..." -ForegroundColor Yellow
Write-Host "Installing LLaVA 1.5..." -ForegroundColor Gray
ollama pull llava:7b
Write-Host "Installing qwen2.5vl..." -ForegroundColor Gray
ollama pull qwen2.5vl:7b
Write-Host "✓ Models downloaded" -ForegroundColor Green

Write-Host "[5/5] Setting up CAPTURE command..." -ForegroundColor Yellow
$captureDir = "$env:USERPROFILE\Downloads\CAPTURE"
$mainScript = "$captureDir\main.ps1"

if (-NOT (Test-Path $captureDir)) {
    New-Item -ItemType Directory -Path $captureDir -Force | Out-Null
}

# Create batch file to call PowerShell script
$batchPath = "$env:LOCALAPPDATA\capture.bat"
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "$mainScript" %*
"@ | Set-Content $batchPath

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$env:LOCALAPPDATA*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$env:LOCALAPPDATA", "Machine")
}

Write-Host "✓ CAPTURE command registered" -ForegroundColor Green
Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "Usage: Open new PowerShell and type 'CAPTURE'" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
