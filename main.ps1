# CAPTURE Main CLI Interface
param([string]$VideoPath = "", [string]$OutputPath = "")

# Import core modules
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\core\banner.ps1"
. "$scriptDir\core\menu.ps1"
. "$scriptDir\core\processor.ps1"
. "$scriptDir\core\chat.ps1"

function Initialize-CAPTURE {
    $global:VideoPath = ""
    $global:OutputPath = "$env:USERPROFILE\Downloads\CAPTURE\output"
    $global:ProcessingComplete = $false
    $global:AnalysisData = $null
    
    if (-NOT (Test-Path $global:OutputPath)) {
        New-Item -ItemType Directory -Path $global:OutputPath -Force | Out-Null
    }
}

function Show-MainMenu {
    Clear-Host
    Show-Banner
    
    Write-Host ""
    Write-Host "MENU:" -ForegroundColor Cyan
    Write-Host "  A - Set video footage path" -ForegroundColor Yellow
    Write-Host "  C - Set output folder for proof clips" -ForegroundColor Yellow
    Write-Host "  D - Start processing video" -ForegroundColor Yellow
    Write-Host "  P - Start querying/chatting about video" -ForegroundColor Yellow
    Write-Host "  E - Exit CAPTURE" -ForegroundColor Yellow
    Write-Host ""
    
    if ($global:VideoPath) {
        Write-Host "Current Video: $global:VideoPath" -ForegroundColor Green
    } else {
        Write-Host "Current Video: NOT SET" -ForegroundColor Red
    }
    
    if ($global:OutputPath) {
        Write-Host "Output Folder: $global:OutputPath" -ForegroundColor Green
    }
    
    Write-Host ""
}

function Main {
    Initialize-CAPTURE
    
    while ($true) {
        Show-MainMenu
        $choice = Read-Host "Enter choice (A/C/D/P/E)"
        
        switch ($choice.ToUpper()) {
            "A" {
                Write-Host ""
                $path = Read-Host "Enter video file path"
                if (Test-Path $path) {
                    $global:VideoPath = $path
                    Write-Host "✓ Video path set" -ForegroundColor Green
                } else {
                    Write-Host "✗ File not found" -ForegroundColor Red
                }
                Read-Host "Press Enter to continue"
            }
            "C" {
                Write-Host ""
                $path = Read-Host "Enter output folder path"
                if (Test-Path $path -PathType Container) {
                    $global:OutputPath = $path
                    Write-Host "✓ Output folder set" -ForegroundColor Green
                } else {
                    Write-Host "✗ Folder not found or creating..." -ForegroundColor Yellow
                    New-Item -ItemType Directory -Path $path -Force | Out-Null
                    $global:OutputPath = $path
                    Write-Host "✓ Output folder created and set" -ForegroundColor Green
                }
                Read-Host "Press Enter to continue"
            }
            "D" {
                if (-NOT $global:VideoPath) {
                    Write-Host "✗ Please set video path first (A)" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                } else {
                    Write-Host ""
                    Write-Host "Starting video processing..." -ForegroundColor Cyan
                    Write-Host "This may take several minutes depending on video length" -ForegroundColor Gray
                    $global:AnalysisData = Process-Video -VideoPath $global:VideoPath
                    $global:ProcessingComplete = $true
                    Write-Host "✓ Processing complete" -ForegroundColor Green
                    Read-Host "Press Enter to continue"
                }
            }
            "P" {
                if (-NOT $global:ProcessingComplete) {
                    Write-Host "✗ Please process video first (D)" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                } else {
                    Start-Chat -AnalysisData $global:AnalysisData -OutputPath $global:OutputPath
                }
            }
            "E" {
                Write-Host ""
                Write-Host "Thank you for using CAPTURE!" -ForegroundColor Cyan
                exit
            }
            default {
                Write-Host "✗ Invalid choice" -ForegroundColor Red
                Read-Host "Press Enter to continue"
            }
        }
    }
}

# Run main
Main
