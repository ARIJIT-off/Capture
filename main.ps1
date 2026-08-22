$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$videoPath = ""
$outputPath = ""
$analysisJson = "$scriptDir\analysis.json"

# Load previous settings if they exist
if (Test-Path "$scriptDir\.capture_config") {
    $config = Get-Content "$scriptDir\.capture_config" | ConvertFrom-Json
    $videoPath = $config.videoPath
    $outputPath = $config.outputPath
}

function Show-Banner {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   CAPTURE - Local CCTV Incident Extraction" -ForegroundColor Cyan
    Write-Host "   Local AI that finds incidents in long CCTV footage" -ForegroundColor Cyan
    Write-Host "   No cloud support - Fully offline" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "MENU:" -ForegroundColor Yellow
    Write-Host "  A - Set video footage path" -ForegroundColor Gray
    Write-Host "  C - Set output folder for proof clips" -ForegroundColor Gray
    Write-Host "  D - Start processing video" -ForegroundColor Gray
    Write-Host "  P - Start querying/chatting about video" -ForegroundColor Gray
    Write-Host "  E - Exit CAPTURE" -ForegroundColor Gray
    Write-Host ""
    
    if ($videoPath) {
        Write-Host "  Video  : $videoPath" -ForegroundColor Green
    } else {
        Write-Host "  Video  : (not set)" -ForegroundColor Red
    }
    
    if ($outputPath) {
        Write-Host "  Output : $outputPath" -ForegroundColor Green
    } else {
        Write-Host "  Output : (not set)" -ForegroundColor Red
    }
    
    if (Test-Path $analysisJson) {
        Write-Host "  Status : READY TO QUERY" -ForegroundColor Green
    } elseif ($videoPath) {
        Write-Host "  Status : READY TO PROCESS" -ForegroundColor Yellow
    } else {
        Write-Host "  Status : SET VIDEO PATH" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Set-VideoPath {
    Write-Host "Enter video file path (or drag file here):" -ForegroundColor Yellow
    $path = Read-Host
    $path = $path -replace '"', ''
    
    if (Test-Path $path) {
        $videoPath = $path
        Write-Host "[OK] Video path set" -ForegroundColor Green
        Save-Config
    } else {
        Write-Host "[ERROR] File not found: $path" -ForegroundColor Red
    }
}

function Set-OutputPath {
    Write-Host "Enter output folder path:" -ForegroundColor Yellow
    $path = Read-Host
    $path = $path -replace '"', ''
    
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    $outputPath = $path
    Write-Host "[OK] Output path set" -ForegroundColor Green
    Save-Config
}

function Start-Processing {
    if (-not $videoPath) {
        Write-Host "[ERROR] Video path not set. Choose 'A' first." -ForegroundColor Red
        return
    }
    
    if (-not $outputPath) {
        $outputPath = "$scriptDir\output"
        New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
    }
    
    Write-Host "[INFO] Processing video..." -ForegroundColor Yellow
    Write-Host "[INFO] This may take 1-3 minutes depending on video length..." -ForegroundColor Yellow
    Write-Host ""
    
    python "$scriptDir\process.py" "$videoPath"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Video processed. Ready to query." -ForegroundColor Green
        Save-Config
    } else {
        Write-Host "[ERROR] Processing failed." -ForegroundColor Red
    }
}

function Start-Querying {
    if (-not (Test-Path $analysisJson)) {
        Write-Host "[ERROR] Video not processed yet. Choose 'D' first." -ForegroundColor Red
        return
    }
    
    if (-not $outputPath) {
        $outputPath = "$scriptDir\output"
    }
    
    Write-Host ""
    python "$scriptDir\chat.py" "$analysisJson" "$outputPath"
}

function Save-Config {
    $config = @{
        videoPath = $videoPath
        outputPath = $outputPath
    }
    $config | ConvertTo-Json | Set-Content "$scriptDir\.capture_config"
}

# Main loop
while ($true) {
    Show-Banner
    Show-Menu
    
    $choice = Read-Host "Enter choice (A/C/D/P/E)"
    $choice = $choice.ToUpper()
    
    switch ($choice) {
        "A" { Set-VideoPath }
        "C" { Set-OutputPath }
        "D" { Start-Processing }
        "P" { Start-Querying }
        "E" { 
            Write-Host "Exiting CAPTURE. Goodbye!" -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "[ERROR] Invalid choice. Try again." -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Read-Host "Press Enter to continue"
    Clear-Host
}
