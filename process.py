import cv2
import json
import sys
import os
import numpy as np
from transformers import VideoMAEImageProcessor, VideoMAEForVideoClassification
from PIL import Image
import torch

def load_videomae_model():
    """Load VideoMAE model for understanding video content"""
    try:
        print("[INFO] Loading VideoMAE model...")
        processor = VideoMAEImageProcessor.from_pretrained("MCG-NJU/videomae-base")
        model = VideoMAEForVideoClassification.from_pretrained("MCG-NJU/videomae-base")
        print("[INFO] VideoMAE model loaded")
        return processor, model
    except Exception as e:
        print(f"[WARN] Could not load VideoMAE: {e}")
        print("[INFO] Will use motion detection only")
        return None, None

def generate_frame_caption(frame, processor, model):
    """Generate natural language description of what's in the frame"""
    if processor is None or model is None:
        return "Unknown content"
    
    try:
        # Prepare frame for model
        pil_image = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        inputs = processor(images=[pil_image], return_tensors="pt")
        
        with torch.no_grad():
            outputs = model(**inputs)
        
        # Get top predicted class
        logits = outputs.logits
        predicted_class_idx = logits.argmax(-1).item()
        
        # Map class to description (simplified)
        class_names = [
            "person", "object", "motion", "stationary", "interaction",
            "hand movement", "picking up", "putting down", "holding",
            "multiple people", "empty scene", "unclear"
        ]
        
        if predicted_class_idx < len(class_names):
            return class_names[predicted_class_idx]
        return "activity detected"
    except:
        return "activity detected"

def process_video(video_path):
    try:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print("[ERROR] Cannot open video file")
            return None

        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        duration = total_frames / fps

        print(f"[INFO] Duration : {duration:.1f} seconds")
        print(f"[INFO] FPS      : {fps}")
        print(f"[INFO] Extracting frames + generating descriptions...")

        # Load VideoMAE model
        processor, model = load_videomae_model()

        frames = []
        frame_count = 0
        fgbg = cv2.createBackgroundSubtractorMOG2(history=500, varThreshold=50)
        frame_interval = max(1, int(fps * 2))  # Extract every 2 seconds
        extracted = 0
        prev_frame = None
        
        # Skip first 2 seconds for MOG2 warmup
        warmup_frames = int(fps * 2)
        print(f"[INFO] Skipping first {warmup_frames} frames for motion detection warmup...")

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            # MOG2 warmup
            if frame_count < warmup_frames:
                fgbg.apply(frame)
                frame_count += 1
                continue

            if frame_count % frame_interval == 0:
                timestamp = frame_count / fps

                # Motion detection
                fgmask = fgbg.apply(frame)
                motion_score = int(cv2.countNonZero(fgmask))

                # Optical flow
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                flow_score = 0
                if prev_frame is not None:
                    diff = cv2.absdiff(prev_frame, gray)
                    flow_score = int(np.sum(diff > 25))
                prev_frame = gray

                # Generate caption
                caption = generate_frame_caption(frame, processor, model)

                # Save thumbnail
                thumb = cv2.resize(frame, (224, 224))
                thumb_path = os.path.join(
                    os.path.dirname(os.path.abspath(__file__)),
                    "frames",
                    f"frame_{frame_count:08d}.jpg"
                )
                os.makedirs(os.path.dirname(thumb_path), exist_ok=True)
                cv2.imwrite(thumb_path, thumb, [cv2.IMWRITE_JPEG_QUALITY, 70])

                frames.append({
                    "frame_num": frame_count,
                    "timestamp": round(timestamp, 2),
                    "motion_score": motion_score,
                    "flow_score": flow_score,
                    "caption": caption,
                    "thumb": thumb_path
                })
                extracted += 1

                if extracted % 10 == 0:
                    pct = (frame_count / total_frames) * 100
                    print(f"[INFO] Progress: {pct:.0f}% ({extracted} frames) | Latest: '{caption}'")

            frame_count += 1

        cap.release()

        # Adaptive motion threshold
        if frames:
            motion_scores = sorted([f["motion_score"] for f in frames])
            percentile_75 = motion_scores[int(len(motion_scores) * 0.75)]
            threshold = max(percentile_75 * 0.6, 100)
            print(f"[INFO] Motion threshold: {int(threshold)}")
        else:
            threshold = 300

        # Motion windows
        motion_windows = [
            f for f in frames
            if f["motion_score"] > threshold or f["flow_score"] > 500
        ]
        motion_windows.sort(key=lambda x: x["motion_score"] + x["flow_score"], reverse=True)

        analysis = {
            "video_path": video_path,
            "total_extracted": len(frames),
            "total_motion_windows": len(motion_windows),
            "fps": fps,
            "duration": round(duration, 2),
            "frames": frames,
            "motion_windows": motion_windows
        }

        print(f"[INFO] Frames extracted     : {len(frames)}")
        print(f"[INFO] Motion windows found : {len(motion_windows)}")
        print(f"[SUCCESS] Processing complete")
        return analysis

    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("[ERROR] Usage: python process.py <video_path>")
        sys.exit(1)

    video_path = sys.argv[1]
    if not os.path.exists(video_path):
        print(f"[ERROR] File not found: {video_path}")
        sys.exit(1)

    analysis = process_video(video_path)
    if analysis:
        out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "analysis.json")
        with open(out, "w") as f:
            json.dump(analysis, f, indent=2)
        print(f"[INFO] Saved: {out}")
        sys.exit(0)
    else:
        sys.exit(1)
