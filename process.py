import cv2
import json
import sys
import os

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
        print(f"[INFO] Frames   : {total_frames}")
        print(f"[INFO] Extracting 1 frame every 2 seconds...")

        frames = []
        frame_count = 0
        fgbg = cv2.createBackgroundSubtractorMOG2()
        frame_interval = max(1, int(fps * 2))
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
                    "frame_num": frame_count,
                    "timestamp": round(timestamp, 2),
                    "motion_score": int(motion_pixels)
                })
                extracted += 1

                if extracted % 50 == 0:
                    print(f"[INFO] Extracted {extracted} frames so far...")

            frame_count += 1

        cap.release()

        motion_windows = [f for f in frames if f["motion_score"] > 200]

        analysis = {
            "video_path": video_path,
            "total_extracted": len(frames),
            "total_motion_windows": len(motion_windows),
            "fps": fps,
            "duration": round(duration, 2),
            "frames": frames,
            "motion_windows": motion_windows
        }

        print(f"[INFO] Total extracted frames : {len(frames)}")
        print(f"[INFO] Motion windows found   : {len(motion_windows)}")
        print(f"[SUCCESS] Analysis complete")

        return analysis

    except Exception as e:
        print(f"[ERROR] {str(e)}")
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
        script_dir = os.path.dirname(os.path.abspath(__file__))
        out_path = os.path.join(script_dir, "analysis.json")
        with open(out_path, "w") as f:
            json.dump(analysis, f, indent=2)
        print(f"[INFO] Saved: {out_path}")
        sys.exit(0)
    else:
        sys.exit(1)
