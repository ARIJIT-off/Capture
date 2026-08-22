import json
import sys
import os
import subprocess
import requests
import base64
import cv2

def query_llava(user_query, frame_data):
    """Send a frame to LLaVA via Ollama and ask about the query"""
    try:
        _, buffer = cv2.imencode(".jpg", frame_data)
        img_b64 = base64.b64encode(buffer).decode("utf-8")

        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llava:7b",
                "prompt": f"Look at this image carefully. Does it show: {user_query}? Reply with YES or NO, then briefly explain what you see.",
                "images": [img_b64],
                "stream": False
            },
            timeout=120
        )

        if response.status_code == 200:
            return response.json().get("response", "")
    except Exception as e:
        print(f"[WARN] LLaVA query failed: {e}")
    return ""

def search_video(analysis_data, user_query, video_path):
    """Search motion windows using LLaVA"""
    motion_windows = analysis_data.get("motion_windows", [])

    if not motion_windows:
        return []

    print(f"[INFO] Checking {len(motion_windows)} motion windows...")

    cap = cv2.VideoCapture(video_path)
    fps = analysis_data.get("fps", 30)
    matches = []

    for i, window in enumerate(motion_windows):
        timestamp = window["timestamp"]
        frame_num = window["frame_num"]

        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_num)
        ret, frame = cap.read()

        if not ret:
            continue

        print(f"[INFO] Checking frame at {int(timestamp)}s... ({i+1}/{len(motion_windows)})")
        result = query_llava(user_query, frame)

        if result and "YES" in result.upper():
            matches.append({
                "timestamp": timestamp,
                "frame_num": frame_num,
                "response": result
            })
            print(f"[MATCH] Found at {int(timestamp//60)}m {int(timestamp%60)}s")

    cap.release()
    return matches

def crop_proof(video_path, start_sec, end_sec, output_path):
    """Use ffmpeg to crop a clip"""
    os.makedirs(output_path, exist_ok=True)
    out_file = os.path.join(output_path, f"proof_{int(start_sec)}s_to_{int(end_sec)}s.mp4")

    cmd = [
        "ffmpeg",
        "-i", video_path,
        "-ss", str(int(start_sec)),
        "-to", str(int(end_sec)),
        "-c", "copy",
        "-y",
        out_file
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"[OK] Proof saved: {out_file}")
        return out_file
    else:
        print(f"[ERROR] FFmpeg failed: {result.stderr}")
        return None

def format_time(seconds):
    m = int(seconds // 60)
    s = int(seconds % 60)
    if m > 0:
        return f"{m}m {s}s"
    return f"{s}s"

def main():
    if len(sys.argv) < 3:
        print("[ERROR] Usage: python chat.py <analysis.json> <output_path>")
        sys.exit(1)

    json_path = sys.argv[1]
    output_path = sys.argv[2]

    if not os.path.exists(json_path):
        print(f"[ERROR] analysis.json not found: {json_path}")
        sys.exit(1)

    with open(json_path, "r") as f:
        analysis_data = json.load(f)

    video_path = analysis_data.get("video_path", "")
    duration = analysis_data.get("duration", 0)

    print("=" * 60)
    print("CAPTURE - Query Interface")
    print(f"Video duration: {format_time(duration)}")
    print(f"Motion windows: {analysis_data.get('total_motion_windows', 0)}")
    print("=" * 60)
    print("Commands: Type query | 'E' to exit | 'Proof' to download clip")
    print("")

    last_matches = []

    while True:
        user_input = input("Query > ").strip()

        if not user_input:
            continue

        if user_input.upper() == "E":
            print("Exiting CAPTURE. Goodbye!")
            break

        if user_input.upper() == "PROOF":
            if not last_matches:
                print("[INFO] No match to download. Run a query first.")
                continue

            best = last_matches[0]
            ts = best["timestamp"]
            start = max(0, ts - 3)
            end = min(duration, ts + 7)

            print(f"[INFO] Cropping from {format_time(start)} to {format_time(end)}...")
            crop_proof(video_path, start, end, output_path)

            cont = input("Continue chatting? (P=yes / E=exit): ").strip().upper()
            if cont == "E":
                print("Exiting CAPTURE. Goodbye!")
                break
            continue

        # Run query
        matches = search_video(analysis_data, user_input, video_path)
        last_matches = matches

        print("")
        if matches:
            print(f"[FOUND] Incident detected in {len(matches)} location(s):")
            for m in matches:
                ts = m["timestamp"]
                print(f"  >> At {format_time(ts)} ({int(ts)}s)")
                print(f"     {m['response'][:120]}")

            best = matches[0]
            ts = best["timestamp"]
            start = max(0, ts - 3)
            end = min(duration, ts + 7)
            print(f"\n[INFO] Incident window: {format_time(start)} --> {format_time(end)}")
            print("")

            action = input("Continue chat (C) or Download proof (Proof)? ").strip().upper()
            if action == "PROOF":
                print(f"[INFO] Cropping from {format_time(start)} to {format_time(end)}...")
                crop_proof(video_path, start, end, output_path)

                cont = input("Continue chatting? (P=yes / E=exit): ").strip().upper()
                if cont == "E":
                    print("Exiting CAPTURE. Goodbye!")
                    break
        else:
            print("[NOT FOUND] No such incident found in this video.")
            print("")

if __name__ == "__main__":
    main()
