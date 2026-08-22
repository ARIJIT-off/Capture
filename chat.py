import json
import sys
import os
import subprocess

def load_clip():
    """Load CLIP model - much faster than LLaVA"""
    print("[INFO] Loading CLIP (torch + torchvision)...")
    print("[INFO] First load can take 30-90+ seconds on some PCs (antivirus")
    print("[INFO] scanning new files, slow disk, etc). This is NORMAL.")
    print("[INFO] Do NOT press Ctrl+C - just let it finish.")

    try:
        import torch
        import clip
        from PIL import Image
        device = "cpu"  # Use CPU since no CUDA GPU
        model, preprocess = clip.load("ViT-B/32", device=device)
        print("[INFO] CLIP model loaded")
        return model, preprocess, device
    except KeyboardInterrupt:
        print("")
        print("[ERROR] Loading was interrupted (Ctrl+C) before it finished.")
        print("[ERROR] This is why it crashed - torch/clip were mid-import.")
        print("[TIP] Run CAPTURE again and just wait, even if it looks stuck.")
        print("[TIP] If it's always slow, add this folder to your antivirus")
        print("[TIP] exclusions list to speed up future loads.")
        return None, None, None
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
        except KeyboardInterrupt:
            print("")
            print("[ERROR] Loading was interrupted (Ctrl+C) before it finished.")
            print("[TIP] Run CAPTURE again and just wait for it to finish.")
            return None, None, None
        except Exception as e:
            print(f"[ERROR] Could not load CLIP: {e}")
            return None, None, None

def search_with_clip(analysis_data, user_query, model, preprocess, device):
    """Use CLIP to semantically match frames to query - multi-query refinement for precision"""
    import torch
    import clip
    from PIL import Image

    frames = analysis_data.get("frames", [])
    if not frames:
        return []

    print(f"[INFO] Running CLIP semantic search on {len(frames)} frames...")
    print(f"[INFO] Query: '{user_query}' (using multi-query refinement)")

    # Multi-query strategy: ask related questions to narrow down exact moment
    related_queries = [
        user_query,
        f"someone {user_query.lower()}",
        f"person {user_query.lower()}",
        f"hand reaching for {user_query.lower()}",
        f"taking {user_query.lower()}",
    ]
    
    # Remove duplicates and tokenize
    related_queries = list(set(related_queries))
    text = clip.tokenize(related_queries).to(device)

    matches = []
    batch_size = 32

    for i in range(0, len(frames), batch_size):
        batch = frames[i:i+batch_size]
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

            similarity = (100.0 * image_features @ text_features.T).softmax(dim=-1)

        for j, (_, frame) in enumerate(images):
            # Score: average of all related queries (higher = more specific match)
            scores = [float(similarity[j][k]) for k in range(len(related_queries))]
            avg_score = sum(scores) / len(scores)
            max_score = max(scores)
            
            # Only include if avg score is high (not just one lucky high match)
            # This filters out false positives
            if avg_score > 0.28 and max_score > 0.40:
                matches.append({
                    "timestamp": frame["timestamp"],
                    "frame_num": frame["frame_num"],
                    "score": round(avg_score, 3),
                    "max_score": round(max_score, 3),
                    "motion_score": frame.get("motion_score", 0)
                })

        pct = min(100, ((i + batch_size) / len(frames)) * 100)
        print(f"[INFO] CLIP search progress: {pct:.0f}%", end="\r")

    print("")

    # Sort by score descending
    matches.sort(key=lambda x: x["score"], reverse=True)

    # Deduplicate - merge matches within 3 seconds of each other (stricter)
    deduped = []
    for m in matches:
        if not deduped or abs(m["timestamp"] - deduped[-1]["timestamp"]) > 3:
            deduped.append(m)

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
                max_pct = int(m.get("max_score", 0) * 100)
                print(f"  [{i+1}] At {format_time(ts)} ({int(ts)}s) — Avg: {score_pct}% | Peak: {max_pct}%")

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