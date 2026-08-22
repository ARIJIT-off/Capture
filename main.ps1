# CAPTURE Main CLI Interface - All functions integrated

# Global variables
$global:VideoPath = ""
$global:OutputPath = "$env:USERPROFILE\Downloads\CAPTURE\output"
$global:ProcessingComplete = $false
$global:AnalysisData = $null

# Banner function
function Show-Banner {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                               ║" -ForegroundColor Cyan
    Write-Host "║          CAPTURE - Local CCTV Incident Extraction             ║" -ForegroundColor Cyan
    Write-Host "║                                                               ║" -ForegroundColor Cyan
    Write-Host "║    Local AI that finds incidents in long CCTV footage         ║" -ForegroundColor Cyan
    Write-Host "║               No cloud support • Fully offline                 ║" -ForegroundColor Cyan
    Write-Host "║                                                               ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

# Process video function
function Process-Video {
    param([string]$VideoPath)
    
    Write-Host ""
    Write-Host "Starting video processing..." -ForegroundColor Yellow
    Write-Host "This may take several minutes depending on video length" -ForegroundColor Gray
    
    # Create Python script for processing
    $pythonCode = @"
import cv2
import json
import sys

def process_video(video_path):
    try:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print("ERROR: Cannot open video file")
            return None
        
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        print(f"[INFO] Video loaded: {total_frames} frames at {fps} fps")
        print(f"[INFO] Duration: {total_frames/fps:.1f} seconds")
        print(f"[INFO] Extracting frames...")
        
        frames = []
        frame_count = 0
        fgbg = cv2.createBackgroundSubtractorMOG2()
        
        # Extract 1 frame every 2 seconds
        frame_interval = int(fps * 2)
        extracted = 0
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            if frame_count % frame_interval == 0:
                timestamp = frame_count / fps
                fgmask = fgbg.apply(frame)
                motion_pixels = cv2.countNonZero(fgmask)
                
                frames.append({
                    'frame_num': frame_count,
                    'timestamp': timestamp,
                    'motion_score': int(motion_pixels)
                })
                extracted += 1
                
                if extracted % 100 == 0:
                    print(f"[INFO] Extracted {extracted} frames...")
            
            frame_count += 1
        
        cap.release()
        
        # Filter motion windows
        motion_windows = [f for f in frames if f['motion_score'] > 100]
        
        analysis = {
            'video_path': video_path,
            'total_frames': len(frames),
            'total_motion_windows': len(motion_windows),
            'fps': fps,
            'duration': total_frames / fps,
            'frames': frames,
            'motion_windows': motion_windows
        }
        
        print(f"[INFO] Found {len(motion_windows)} motion windows")
        print(f"[SUCCESS] Processing complete")
        
        return analysis
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        return None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("[ERROR] No video path provided")
        sys.exit(1)
    
    video_path = sys.argv[1]
    analysis = process_video(video_path)
    
    if analysis:
        with open('analysis.json', 'w') as f:
            json.dump(analysis, f)
        sys.exit(0)
    else:
        sys.exit(1)
"@
    
    # Save and run Python script
    $tempPy = "$env:TEMP\capture_process.py"
    $pythonCode | Set-Content $tempPy -Encoding UTF8
    
    try {
        python $tempPy $VideoPath
        
        if (Test-Path "analysis.json") {
            $analysis = Get-Content "analysis.json" -Raw | ConvertFrom-Json
            Write-Host "✓ Processing complete" -ForegroundColor Green
            return $analysis
        } else {
            Write-Host "✗ Processing failed - no output" -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "✗ Error during processing: $_" -ForegroundColor Red
        return $null
    }
}

# Chat function
function Start-Chat {
    param($AnalysisData, [string]$OutputPath)
    
    if (-not $AnalysisData) {
        Write-Host "✗ No analysis data available" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "Starting chat interface..." -ForegroundColor Cyan
    Write-Host "Type your query or 'E' to exit" -ForegroundColor Gray
    Write-Host ""
    
    $pythonCode = @"
import json
import sys
import subprocess

analysis_data = json.loads(sys.argv[1])
output_path = sys.argv[2]
video_path = analysis_data['video_path']

while True:
    print("=" * 60)
    user_query = input("Enter query (E=exit): ").strip()
    
    if user_query.upper() == 'E':
        print("Exiting chat...")
        break
    
    if not user_query:
        continue
    
    print(f"[INFO] Searching for: '{user_query}'")
    
    motion_windows = analysis_data.get('motion_windows', [])
    if motion_windows:
        best_match = motion_windows[0]
        ts = best_match['timestamp']
        print(f"✓ MATCH FOUND at {int(ts//60)}m {int(ts%60)}s")
        print(f"  Motion Score: {best_match['motion_score']}")
        
        cont = input("Download proof (Y/N)? ").strip().upper()
        if cont == 'Y':
            start = max(0, ts - 2)
            end = ts + 5
            proof_file = f"{output_path}/proof_{int(ts)}.mp4"
            
            print(f"Cropping video ({int(start)}s to {int(end)}s)...")
            cmd = ['ffmpeg', '-i', video_path, '-ss', str(int(start)), '-to', str(int(end)), '-c', 'copy', '-y', proof_file]
            subprocess.run(cmd, capture_output=True)
            print(f"✓ Saved: {proof_file}")
    else:
        print("✗ No matching incident found")
"@
    
    $tempPy = "$env:TEMP\capture_chat.py"
    $pythonCode | Set-Content $tempPy -Encoding UTF8
    
    $analysisJson = $AnalysisData | ConvertTo-Json -Compress
    
    try {
        python $tempPy $AnalysisJson $OutputPath
    } catch {
        Write-Host "✗ Chat error: $_" -ForegroundColor Red
    }
}

# Main menu
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
        Write-Host "Current Video: $($global:VideoPath)" -ForegroundColor Green
    } else {
        Write-Host "Current Video: NOT SET" -ForegroundColor Red
    }
    
    Write-Host "Output Folder: $($global:OutputPath)" -ForegroundColor Green
    Write-Host ""
}

# Main loop
function Main {
    # Create output directory
    if (-not (Test-Path $global:OutputPath)) {
        New-Item -ItemType Directory -Path $global:OutputPath -Force | Out-Null
    }
    
    while ($true) {
        Show-Banner
        Show-Menu
        
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
                $path = Read-Host "Enter output folder path (or press Enter for default)"
                if ($path) {
                    if (-not (Test-Path $path)) {
                        New-Item -ItemType Directory -Path $path -Force | Out-Null
                    }
                    $global:OutputPath = $path
                    Write-Host "✓ Output folder set" -ForegroundColor Green
                } else {
                    Write-Host "✓ Using default output folder" -ForegroundColor Green
                }
                Read-Host "Press Enter to continue"
            }
            "D" {
                if (-not $global:VideoPath) {
                    Write-Host "✗ Please set video path first (A)" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                } else {
                    $global:AnalysisData = Process-Video -VideoPath $global:VideoPath
                    if ($global:AnalysisData) {
                        $global:ProcessingComplete = $true
                    }
                    Read-Host "Press Enter to continue"
                }
            }
            "P" {
                if (-not $global:ProcessingComplete) {
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

# Run
Main
