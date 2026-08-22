import json
import sys
import os
import subprocess

def load_clip():
    """Load CLIP model - much faster than LLaVA"""
    try:
        import torch
        import clip
        from PIL import Image
        device = "cpu"  # Use CPU since no CUDA GPU
        model, preprocess = clip.load("ViT-B/32", device=device)
        print("[INFO] CLIP model loaded")
        return model, preprocess, device
    except ImportError:
        print("[WARN] CLIP not installed. Installing now...")
        subprocess.run([sys.executable, "-m", "pip", "install", "git+https://github.com/openai/CLIP.git", "Pillow", "--quiet"], check=False)
        try:
            import torch
            import clip
            from PIL import Image
            device = "cpu"
            model, preprocess = clip.load("ViT-B/32", device=device)
            print("[INFO] CLIP model loaded")
            return model, preprocess, device
        except Exception as e:
            print(f"[ERROR] Could not load CLIP: {e}")
            return None, None, None

def search_with_clip(analysis_data, user_query, model, preprocess, device):
    """Use CLIP on motion windows only - motion-first filtering for accuracy"""
    import torch
    import clip
    from PIL import Image

    # Get motion windows (frames with significant movement)
    motion_windows = analysis_data.get("motion_windows", [])
    all_frames = analysis_data.get("frames", [])
    
    # Filter out frame 0 (MOG2 false positive on first frame) and extreme outliers
    motion_windows = [
        f for f in motion_windows 
        if f["frame_num"] > 0 and f.get("motion_score", 0) < 100000
    ]
    
    if not motion_windows:
        print("[INFO] No valid motion detected. Searching all frames...")
        search_frames = [f for f in all_frames if f["frame_num"] > 0]
    else:
        print(f"[INFO] Found {len(motion_windows)} motion windows (filtered). Searching those first...")
        search_frames = motion_windows

    if not search_frames:
        return []

    print(f"[INFO] Running CLIP search on {len(search_frames)} high-motion frames...")
    print(f"[INFO] Query: '{user_query}'")

    # Encode the text query
    text = clip.tokenize([user_query]).to(device)

    matches = []
    batch_size = 32

    for i in range(0, len(search_frames), batch_size):
        batch = search_frames[i:i+batch_size]
        images = []

        for frame in batch:
            thumb_path = frame.get("thumb", "")
            if thumb_path and os.path.exists(thumb_path):
                try:
                    img = preprocess(Image.open(thumb_path)).unsqueeze(0).to(device)
                    images.append((img, frame))
                except:
                    continue

        if not images:
            continue

        img_tensors = torch.cat([img for img, _ in images])

        with torch.no_grad():
            image_features = model.encode_image(img_tensors)
            text_features = model.encode_text(text)

            image_features /= image_features.norm(dim=-1, keepdim=True)
            text_features /= text_features.norm(dim=-1, keepdim=True)

            # Use direct cosine similarity (0-1) instead of softmax
            # softmax normalizes across frames making them all equal
            similarity = (image_features @ text_features.T).squeeze(-1)  # Shape: [batch_size]

        for j, (_, frame) in enumerate(images):
            # Direct cosine similarity (0-1 range, already normalized)
            clip_score = float(similarity[j])
            motion = frame.get("motion_score", 0)
            
            # Boost score based on motion (frames with movement rank higher)
            # motion_score typically 300-5000 for moving objects
            motion_multiplier = 1.0 + (min(motion, 2000) / 2000.0) * 0.5  # Max +0.5 boost
            final_score = clip_score * motion_multiplier
            
            if final_score > 0.15:
                matches.append({
                    "timestamp": frame["timestamp"],
                    "frame_num": frame["frame_num"],
                    "score": round(final_score, 3),
                    "clip_score": round(clip_score, 3),
                    "motion_score": motion
                })

        pct = min(100, ((i + batch_size) / len(search_frames)) * 100)
        print(f"[INFO] Progress: {pct:.0f}%", end="\r")

    print("")

    # Sort by score descending, with motion as tiebreaker
    matches.sort(key=lambda x: (
        x["motion_score"] > 10000,  # Primary: high-motion frames first
        x["score"],                  # Secondary: CLIP score
        -x["motion_score"]           # Tertiary: higher motion wins ties
    ), reverse=True)

    # Deduplicate - merge matches within 2 seconds
    deduped = []
    for m in matches:
        if not deduped or abs(m["timestamp"] - deduped[-1]["timestamp"]) > 2:
            deduped.append(m)

    if not matches:
        print(f"[INFO] No matches found in motion windows with query '{user_query}'")
        print(f"[INFO] Try: 'bottle', 'person', 'hand', or 'object'")

    return deduped

def crop_proof(video_path, start_sec, end_sec, output_path, duration):
    """Use ffmpeg to crop a clip"""
    os.makedirs(output_path, exist_ok=True)
    out_file = os.path.join(output_path, f"proof_{int(start_sec)}s_to_{int(end_sec)}s.mp4")
    end_sec = min(end_sec, duration)

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
        print(f"[ERROR] FFmpeg failed: {result.stderr[-200:]}")
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
    print("CAPTURE - Query Interface (CLIP-powered)")
    print(f"Video duration  : {format_time(duration)}")
    print(f"Frames indexed  : {analysis_data.get('total_extracted', 0)}")
    print(f"Motion windows  : {analysis_data.get('total_motion_windows', 0)}")
    print("=" * 60)

    # Load CLIP once at startup
    model, preprocess, device = load_clip()
    if model is None:
        print("[ERROR] Could not load CLIP model. Exiting.")
        sys.exit(1)

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

        # Run CLIP search
        matches = search_with_clip(analysis_data, user_input, model, preprocess, device)
        last_matches = matches

        print("")
        if matches:
            print(f"[FOUND] {len(matches)} match(es) detected:")
            for i, m in enumerate(matches[:5]):  # Show top 5
                ts = m["timestamp"]
                score_pct = int(m["score"] * 100)
                print(f"  [{i+1}] At {format_time(ts)} ({int(ts)}s) — Confidence: {score_pct}%")

            best = last_matches[0]
            ts = best["timestamp"]
            start = max(0, ts - 3)
            end = min(duration, ts + 7)
            print(f"\n  Best match: {format_time(ts)}")
            print(f"  Clip range: {format_time(start)} --> {format_time(end)}")
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
            print("[NOT FOUND] No such incident detected in this video.")
            print("")

if __name__ == "__main__":
    main()