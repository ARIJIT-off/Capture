# CAPTURE Main CLI Interface

$global:VideoPath = ""
$global:OutputPath = "$env:USERPROFILE\Downloads\CAPTURE\output"
$global:ProcessingComplete = $false
$global:AnalysisData = $null
$global:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Banner {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   CAPTURE - Local CCTV Incident Extraction" -ForegroundColor Cyan
    Write-Host "   Local AI that finds incidents in long CCTV footage" -ForegroundColor Cyan
    Write-Host "   No cloud support - Fully offline" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
}

function Show-Menu {
    Write-Host ""
    Write-Host "MENU:" -ForegroundColor Cyan
    Write-Host "  A - Set video footage path" -ForegroundColor Yellow
    Write-Host "  C - Set output folder for proof clips" -ForegroundColor Yellow
    Write-Host "  D - Start processing video" -ForegroundColor Yellow
    Write-Host "  P - Start querying/chatting about video" -ForegroundColor Yellow
    Write-Host "  E - Exit CAPTURE" -ForegroundColor Yellow
    Write-Host ""
    if ($global:VideoPath) {
        Write-Host "  Video  : $($global:VideoPath)" -ForegroundColor Green
    } else {
        Write-Host "  Video  : NOT SET" -ForegroundColor Red
    }
    Write-Host "  Output : $($global:OutputPath)" -ForegroundColor Green
    if ($global:ProcessingComplete) {
        Write-Host "  Status : READY TO QUERY" -ForegroundColor Green
    } else {
        Write-Host "  Status : NOT PROCESSED" -ForegroundColor Gray
    }
    Write-Host ""
}

function Run-Process {
    $pyScript = "$global:ScriptDir\process.py"
    if (-not (Test-Path $pyScript)) {
        Write-Host "X process.py not found in $global:ScriptDir" -ForegroundColor Red
        return $null
    }

    Write-Host "Processing video..." -ForegroundColor Yellow
    python $pyScript $global:VideoPath

    $jsonPath = "$global:ScriptDir\analysis.json"
    if (Test-Path $jsonPath) {
        $data = Get-Content $jsonPath -Raw | ConvertFrom-Json
        Write-Host "OK Processing complete" -ForegroundColor Green
        return $data
    } else {
        Write-Host "X Processing failed" -ForegroundColor Red
        return $null
    }
}

function Run-Chat {
    $pyScript = "$global:ScriptDir\chat.py"
    if (-not (Test-Path $pyScript)) {
        Write-Host "X chat.py not found in $global:ScriptDir" -ForegroundColor Red
        return
    }

    $jsonPath = "$global:ScriptDir\analysis.json"
    python $pyScript $jsonPath $global:OutputPath
}

function Main {
    if (-not (Test-Path $global:OutputPath)) {
        New-Item -ItemType Directory -Path $global:OutputPath -Force | Out-Null
    }

    while ($true) {
        Show-Banner
        Show-Menu

        $choice = Read-Host "Enter choice (A/C/D/P/E)"

        switch ($choice.ToUpper().Trim()) {
            "A" {
                $path = Read-Host "Enter full video file path"
                $path = $path.Trim().Trim('"')
                if (Test-Path $path) {
                    $global:VideoPath = $path
                    Write-Host "OK Video path set" -ForegroundColor Green
                } else {
                    Write-Host "X File not found: $path" -ForegroundColor Red
                }
                Read-Host "Press Enter to continue"
            }
            "C" {
                $path = Read-Host "Enter output folder path (Enter = keep default)"
                if ($path.Trim()) {
                    $path = $path.Trim().Trim('"')
                    if (-not (Test-Path $path)) {
                        New-Item -ItemType Directory -Path $path -Force | Out-Null
                    }
                    $global:OutputPath = $path
                    Write-Host "OK Output folder set" -ForegroundColor Green
                } else {
                    Write-Host "OK Keeping default: $global:OutputPath" -ForegroundColor Green
                }
                Read-Host "Press Enter to continue"
            }
            "D" {
                if (-not $global:VideoPath) {
                    Write-Host "X Set video path first (press A)" -ForegroundColor Red
                } else {
                    $global:AnalysisData = Run-Process
                    if ($global:AnalysisData) {
                        $global:ProcessingComplete = $true
                    }
                }
                Read-Host "Press Enter to continue"
            }
            "P" {
                if (-not $global:ProcessingComplete) {
                    Write-Host "X Process video first (press D)" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                } else {
                    Run-Chat
                }
            }
            "E" {
                Write-Host "Thank you for using CAPTURE!" -ForegroundColor Cyan
                exit
            }
            default {
                Write-Host "X Invalid choice. Use A, C, D, P or E" -ForegroundColor Red
                Read-Host "Press Enter to continue"
            }
        }
    }
}

Main
