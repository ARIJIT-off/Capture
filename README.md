# CAPTURE - Local CCTV Incident Extraction

**AI-powered incident detection for long CCTV footage. Fully offline, no cloud, no GPU required.**

## Features

- 🎥 **Process long videos** - Extract key moments from hours of footage
- 🧠 **AI-powered understanding** - Uses VideoMAE to understand what's happening in each frame
- 🔍 **Natural language queries** - Search for incidents using simple descriptions
- ⚡ **Fast & offline** - Runs completely locally on your PC
- 🎯 **Precise timestamps** - Get exact moments when incidents occur
- 📹 **Auto proof clips** - Generate short proof clips of detected incidents

## Installation

### Requirements
- Windows 10/11
- Python 3.10+
- 8GB RAM (2GB GPU recommended)

### Quick Setup

```powershell
# Download and run installer
irm https://raw.githubusercontent.com/ARIJIT-off/Capture/main/install.ps1 | iex
```

Then restart PowerShell and type:
```powershell
CAPTURE
```

## Usage

### Step 1: Set Video Path
- Launch CAPTURE
- Press `A` to set your video file path

### Step 2: Process Video
- Press `D` to analyze the video
- Wait for processing (1-3 minutes depending on video length)
- System will extract frames and generate descriptions

### Step 3: Query Incidents
- Press `P` to enter query mode
- Type what you're looking for: **"girl picking up airpod"**, **"person stealing bottle"**, etc.
- System finds matching moments and shows exact timestamps
- Press **"Proof"** to download a clip of the incident

## Query Examples

**Good queries:**
- "person picking up object"
- "girl with hand"
- "motion at table"
- "person entering"
- "hand reaching"

**Works for:**
- Theft/stealing
- Picking up objects
- Person interactions
- Suspicious behavior
- Any activity with movement

## System Architecture

```
Video → Extract Frames → VideoMAE Captions → Motion Detection → Caption Search → Proof Clip
```

### Process Flow

1. **process.py** - Extracts frames, generates AI captions, detects motion
2. **chat.py** - Matches your queries against frame captions
3. Outputs exact timestamp + proof video clip

## Performance

| Aspect | Specification |
|--------|---------------|
| Video length | Up to 6+ hours |
| Processing speed | ~10-15 FPS on CPU |
| Query speed | <1 second |
| Proof clip generation | 2-5 seconds |
| Model size | ~350MB |
| RAM usage | 2-4GB |
| GPU support | Optional (CPU works fine) |

## Troubleshooting

### Slow processing
- Normal on CPU - be patient
- First model load takes 30-60 seconds
- Subsequent runs are faster

### No matches found
- Try simpler query terms
- Use keywords from what you see: "person", "hand", "object"
- Check query spelling

### FFmpeg errors
- Ensure FFmpeg is installed: `ffmpeg -version`
- If not installed: `choco install ffmpeg` (requires Chocolatey)

## License

MIT License - See LICENSE file

## Support

For issues, create a GitHub issue or contact the development team.

---

**CAPTURE** - Making CCTV analysis simple, private, and powerful.
