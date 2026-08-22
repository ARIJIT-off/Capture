function Start-Chat {
    param(
        $AnalysisData,
        [string]$OutputPath
    )
    
    $pythonScript = @"
import requests
import json
import sys
import subprocess
from datetime import datetime

def query_video(analysis_data, user_query):
    """Query video using LLaVA"""
    
    matches = []
    print(f"[INFO] Searching for: '{user_query}'")
    
    motion_windows = analysis_data.get('motion_windows', [])
    
    for motion in motion_windows[:50]:  # Limit to first 50 motion windows for speed
        timestamp = motion['timestamp']
        
        try:
            # Query via Ollama
            response = requests.post('http://localhost:11434/api/generate', json={
                'model': 'llava:7b',
                'prompt': f"Looking at this frame, does it show: {user_query}? Answer YES or NO with confidence (0-100).",
                'stream': False
            }, timeout=30)
            
            if response.status_code == 200:
                result = response.json()['response'].upper()
                if 'YES' in result:
                    try:
                        confidence = int(''.join(filter(str.isdigit, result.split('CONFIDENCE')[-1][:3]))) if 'CONFIDENCE' in result else 75
                    except:
                        confidence = 75
                    
                    if confidence > 60:
                        matches.append({
                            'timestamp': timestamp,
                            'confidence': confidence,
                            'response': result
                        })
        except Exception as e:
            pass
    
    return matches

def crop_video(video_path, start_time, end_time, output_file):
    """Crop video using FFmpeg"""
    cmd = [
        'ffmpeg',
        '-i', video_path,
        '-ss', str(start_time),
        '-to', str(end_time),
        '-c', 'copy',
        '-y',
        output_file
    ]
    subprocess.run(cmd, capture_output=True)

def main():
    analysis_data = json.loads(sys.argv[1])
    output_path = sys.argv[2]
    video_path = analysis_data['video_path']
    
    while True:
        print("\n" + "="*60)
        user_query = input("Enter your query (or 'E' to exit, 'Proof' to download): ").strip()
        
        if user_query.upper() == 'E':
            print("Exiting chat...")
            break
        
        if user_query.upper() == 'PROOF':
            print("Proof download initiated...")
            continue
        
        matches = query_video(analysis_data, user_query)
        
        if matches:
            print(f"\n✓ MATCH FOUND!")
            best_match = max(matches, key=lambda x: x['confidence'])
            timestamp = best_match['timestamp']
            confidence = best_match['confidence']
            
            print(f"  Timestamp: {int(timestamp//60)}m {int(timestamp%60)}s")
            print(f"  Confidence: {confidence}%")
            print(f"  Details: {best_match['response'][:100]}...")
            
            # Ask for continuation
            continuation = input("\nContinue chatting (C) or download proof (Proof)? ").strip().upper()
            
            if continuation == 'PROOF':
                # Auto-crop around match
                start = max(0, timestamp - 2)
                end = timestamp + 5
                output_file = f"{output_path}/proof_{int(datetime.now().timestamp())}.mp4"
                
                print(f"Cropping video from {start}s to {end}s...")
                crop_video(video_path, start, end, output_file)
                print(f"✓ Proof saved: {output_file}")
                
                continue_after = input("\nContinue chatting (P) or exit (E)? ").strip().upper()
                if continue_after == 'E':
                    break
        else:
            print("\n✗ No matching incident found")
            print("  This incident does not appear in the video.")

if __name__ == '__main__':
    analysis_data = json.loads(sys.argv[1])
    output_path = sys.argv[2]
    video_path = analysis_data['video_path']
    
    while True:
        user_query = input("\nEnter query (or 'E' to exit): ").strip()
        
        if user_query.upper() == 'E':
            break
        
        matches = query_video(analysis_data, user_query)
        
        if matches:
            best_match = max(matches, key=lambda x: x['confidence'])
            ts = best_match['timestamp']
            print(f"✓ Found at {int(ts//60)}m {int(ts%60)}s (Confidence: {best_match['confidence']}%)")
        else:
            print("✗ Not found in video")
"@
    
    $tempPy = "$env:TEMP\capture_chat.py"
    $pythonScript | Set-Content $tempPy
    
    $analysisJson = $AnalysisData | ConvertTo-Json -Compress
    
    python $tempPy $AnalysisJson $OutputPath
}
