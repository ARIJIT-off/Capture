function Process-Video {
    param([string]$VideoPath)
    
    $pythonScript = @"
import cv2
import json
import sys
from pathlib import Path
import subprocess
import time

def extract_frames(video_path, frame_interval=2):
    """Extract 1 frame every N seconds"""
    cap = cv2.VideoCapture(video_path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    frames_to_extract = int(fps * frame_interval)
    frame_count = 0
    extracted = []
    
    print(f"[INFO] Total frames: {total_frames}, FPS: {fps}")
    print(f"[INFO] Extracting 1 frame every {frame_interval} seconds...")
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        if frame_count % frames_to_extract == 0:
            timestamp = frame_count / fps
            extracted.append({
                'frame_num': frame_count,
                'timestamp': timestamp,
                'data': frame
            })
        frame_count += 1
    
    cap.release()
    print(f"[INFO] Extracted {len(extracted)} frames")
    return extracted

def detect_motion(frames):
    """Detect motion windows using optical flow"""
    fgbg = cv2.createBackgroundSubtractorMOG2()
    motion_windows = []
    
    print("[INFO] Detecting motion windows...")
    
    for i, frame_obj in enumerate(frames):
        frame = frame_obj['data']
        fgmask = fgbg.apply(frame)
        motion_pixels = cv2.countNonZero(fgmask)
        
        if motion_pixels > 100:  # Threshold for motion
            motion_windows.append({
                'frame_num': frame_obj['frame_num'],
                'timestamp': frame_obj['timestamp'],
                'motion_score': motion_pixels
            })
    
    print(f"[INFO] Found {len(motion_windows)} motion windows")
    return motion_windows

def query_with_llava(frames, motion_windows, query):
    """Query frames using LLaVA via Ollama"""
    import requests
    import base64
    
    matches = []
    print(f"[INFO] Querying frames for: '{query}'")
    
    for motion in motion_windows:
        frame_num = motion['frame_num']
        timestamp = motion['timestamp']
        
        # Find frame data
        frame_data = next((f for f in frames if f['frame_num'] == frame_num), None)
        if not frame_data:
            continue
        
        # Encode frame to base64
        _, buffer = cv2.imencode('.jpg', frame_data['data'])
        img_base64 = base64.b64encode(buffer).decode()
        
        try:
            # Query via Ollama
            response = requests.post('http://localhost:11434/api/generate', json={
                'model': 'llava:7b',
                'prompt': f"Does this image show: {query}? Answer YES or NO only.",
                'images': [img_base64],
                'stream': False
            }, timeout=30)
            
            if response.status_code == 200:
                result = response.json()['response']
                if 'YES' in result.upper():
                    matches.append({
                        'timestamp': timestamp,
                        'confidence': 0.8,
                        'description': result
                    })
        except Exception as e:
            print(f"[WARN] Ollama query failed: {e}")
    
    return matches

def main():
    video_path = sys.argv[1]
    
    try:
        frames = extract_frames(video_path, frame_interval=2)
        motion_windows = detect_motion(frames)
        
        # Save analysis data
        analysis = {
            'video_path': video_path,
            'total_frames': len(frames),
            'motion_windows': motion_windows,
            'frames': [(f['frame_num'], f['timestamp']) for f in frames]
        }
        
        with open('analysis.json', 'w') as f:
            json.dump(analysis, f)
        
        print("[SUCCESS] Video analysis complete")
        return 0
    except Exception as e:
        print(f"[ERROR] {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
"@
    
    # Save Python script temporarily
    $tempPy = "$env:TEMP\capture_process.py"
    $pythonScript | Set-Content $tempPy
    
    # Run Python script
    python $tempPy $VideoPath
    
    # Read analysis results
    if (Test-Path "analysis.json") {
        $analysisData = Get-Content "analysis.json" | ConvertFrom-Json
        return $analysisData
    }
    
    return $null
}
