import json
import sys
import os
import subprocess
from difflib import SequenceMatcher

def semantic_match_score(query, caption):
    """Calculate semantic similarity between query and caption"""
    query_lower = query.lower()
    caption_lower = caption.lower()
    
    keywords = query_lower.split()
    matches = sum(1 for kw in keywords if kw in caption_lower)
    keyword_score = matches / len(keywords) if keywords else 0
    
    seq_score = SequenceMatcher(None, query_lower, caption_lower).ratio()
    
    return (keyword_score * 0.6) + (seq_score * 0.4)

def search_with_captions(analysis_data, user_query):
    """Search through frame captions for matches"""
    frames = analysis_data.get("frames", [])
    motion_windows = analysis_data.get("motion_windows", [])
    
    if not frames:
        return []
    
    print(f"[INFO] Searching {len(frames)} frames for: '{user_query}'")
    
    search_frames = motion_windows if motion_windows else frames
    
    matches = []
    for frame in search_frames:
        caption = frame.get("caption", "unknown")
        score = semantic_match_score(user_query, caption)
        
        if score > 0.15:
            matches.append({
                "timestamp": frame["timestamp"],
                "frame_num": frame["frame_num"],
                "score": round(score, 3),
                "caption": caption,
                "motion_score": frame.get("motion_score", 0)
            })
    
    matches.sort(key=lambda x: (x["score"], x["motion_score"]), reverse=True)
    
    deduped = []
    for m in matches:
        if not deduped or abs(m["timestamp"] - deduped[-1]["timestamp"]) > 2:
            deduped.append(m)
    
    return deduped

def crop_proof(video_path, start_sec, end_sec, output_path, duration):
    """Crop proof clip from video"""
    os.makedirs(output_path, exist_ok=True)
    out_file = os.path.join(output_path, f"proof_{int(start_sec)}s_to_{int(end_sec)}s.mp4")
    end_sec = min(end_sec, duration)

    cmd = [
        "ffmpeg",
        "-i", video_path,
        "-ss", str(int(start_sec)),
        "-to", str(int(end_sec)),
        "-c:v", "libx264",
        "-c:a", "aac",
        "-crf", "23",
        "-y",
        out_file
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"[OK] Proof saved: {out_file}")
        return out_file
    else:
        print(f"[ERROR] FFmpeg failed")
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
        print(f"[ERROR] analysis.json not found")
        sys.exit(1)

    with open(json_path, "r") as f:
        analysis_data = json.load(f)

    video_path = analysis_data.get("video_path", "")
    duration = analysis_data.get("duration", 0)

    print("=" * 60)
    print("CAPTURE - Query Interface (Caption-powered)")
    print(f"Video duration  : {format_time(duration)}")
    print(f"Frames indexed  : {analysis_data.get('total_extracted', 0)}")
    print(f"Motion windows  : {analysis_data.get('total_motion_windows', 0)}")
    print("=" * 60)
    print("")
    print("Commands: type query | 'Proof' to download | 'E' to exit")
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
                print("[INFO] No match yet. Run a query first.")
                continue

            best = last_matches[0]
            ts = best["timestamp"]
            start = max(0, ts - 3)
            end = min(duration, ts + 7)
            print(f"[INFO] Cropping {format_time(start)} --> {format_time(end)}...")
            crop_proof(video_path, start, end, output_path, duration)

            cont = input("Continue chatting? (C=yes / E=exit): ").strip().upper()
            if cont == "E":
                print("Goodbye!")
                break
            continue

        matches = search_with_captions(analysis_data, user_input)
        last_matches = matches

        try:
            os.makedirs(output_path, exist_ok=True)
            summary_file = os.path.join(output_path, "summary.txt")
            with open(summary_file, "a") as sf:
                sf.write(f"{user_input}\n")
                for m in matches:
                    score_pct = int(m["score"] * 100)
                    sf.write(f"Frame {m['frame_num']} ({m['timestamp']}s) | Query: {user_input} | Match: {score_pct}%\n")
                sf.write("==================\n")
        except Exception as e:
            print(f"[WARN] Could not append to summary.txt: {e}")

        print("")
        if matches:
            print(f"[FOUND] {len(matches)} match(es) detected:")
            for i, m in enumerate(matches[:5]):
                ts = m["timestamp"]
                score_pct = int(m["score"] * 100)
                caption = m["caption"]
                print(f"  [{i+1}] At {format_time(ts)} ({int(ts)}s)")
                print(f"       Caption: '{caption}' | Match: {score_pct}%")
                print()

            best = last_matches[0]
            ts = best["timestamp"]
            start = max(0, ts - 3)
            end = min(duration, ts + 7)
            print(f"Best match: {format_time(ts)}")
            print(f"Clip range: {format_time(start)} --> {format_time(end)}")
            print("")

            action = input("Continue (C) or Download proof (Proof)? ").strip().upper()
            if action == "PROOF":
                print(f"[INFO] Cropping...")
                crop_proof(video_path, start, end, output_path, duration)
                cont = input("Continue chatting? (C=yes / E=exit): ").strip().upper()
                if cont == "E":
                    print("Goodbye!")
                    break
        else:
            print("[NOT FOUND] No matching frames found for your query.")
            print("[TIP] Try: 'person', 'hand', 'picking up', 'girl', etc.")
            print("")

if __name__ == "__main__":
    main()
