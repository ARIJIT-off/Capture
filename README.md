# CAPTURE - Local CCTV Incident Extraction

**AI-powered incident detection for long CCTV footage. Fully offline, no cloud support.**

## Features

- 🎥 **Process any length video** - Extract key moments from hours of footage
- 🧠 **AI understands video** - BLIP image captioning describes what happens in each frame
- 🔍 **Natural language search** - Query incidents using simple descriptions
- ⚡ **Fully offline** - Runs completely locally on your PC
- 🎯 **Precise timestamps** - Get exact moments when incidents occur
- 📹 **Auto proof clips** - Generate short video clips of detected incidents

## Installation

### Requirements
- Windows 10/11
- Python 3.10+
- 8GB RAM minimum

### Setup Command

```powershell
irm https://raw.githubusercontent.com/ARIJIT-off/Capture/main/install.ps1 | iex
```

Then close and reopen PowerShell, then type:
```powershell
CAPTURE
```

## Usage

### Step 1: Set Video Path
- Press **A** to set your video file path

### Step 2: Process Video
- Press **D** to analyze the video (takes 1-3 minutes)
- System extracts frames and generates AI descriptions

### Step 3: Query Incidents
- Press **P** to query mode
- Type what you're looking for: "girl picking up airpod", "person stealing bottle", etc.
- Press **"Proof"** to download proof clip

## Query Examples

**Good queries:**
- "person picking up object"
- "girl with hand"
- "person entering room"
- "hand reaching for"
- "someone taking"

## System Architecture

```
Video → Extract Frames → AI Captions → Motion Detection → Caption Search → Proof Clip
```

**Process:**
1. `process.py` - Extracts frames, generates BLIP captions, detects motion
2. `chat.py` - Matches queries against captions using semantic similarity
3. Output - Exact timestamp + proof video clip

## Performance

| Aspect | Value |
|--------|-------|
| Video length | Up to 6+ hours |
| Processing | ~10-15 FPS |
| Query time | <1 second |
| Proof clip | 2-5 seconds |
| Model size | ~700MB |
| RAM usage | 2-4GB |

## Troubleshooting

### Slow processing
- Normal on CPU - first model load takes 30-60 seconds
- Subsequent videos are faster

### No matches found
- Try simpler query terms
- Use keywords: "person", "hand", "object"
- Check spelling

### FFmpeg error
- Install: `choco install ffmpeg` (needs Chocolatey)

## License

MIT License - See LICENSE file

---

**CAPTURE** - Making CCTV analysis simple and private.
