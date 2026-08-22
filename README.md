# CAPTURE - Offline CCTV Incident Extraction

Local AI pipeline for finding incidents in long CCTV footage without cloud support.

## Quick Start

### 1. Installation

```powershell
irm https://raw.githubusercontent.com/ARIJIT-off/Capture/main/install.ps1 | iex
```

**Requirements:**
- Windows 10+
- Python 3.8+
- FFmpeg
- Administrator access (for install)

### 2. Usage

Open PowerShell and type:
```powershell
CAPTURE
```

### 3. Workflow

1. **A** - Set video file path
2. **C** - Set output folder (where proof.mp4 saves)
3. **D** - Process video (extracts frames, detects motion)
4. **P** - Chat/Query about video
5. **E** - Exit

## How It Works

### Stage 1: Frame Extraction
- Extracts 1 frame every 2 seconds (reduces 6-hour video to ~10,800 frames)
- Stores frame metadata and timestamps

### Stage 2: Motion Detection
- Uses OpenCV MOG2 background subtraction
- Identifies windows with movement
- Filters out static scenes (faster processing)

### Stage 3: Semantic Matching
- User enters natural language query: "someone picked up a phone"
- LLaVA 1.5 model analyzes motion-detected frames
- Matches frames against query with confidence scoring

### Stage 4: Incident Localization
- Returns exact timestamp of incident
- Example: "Incident found at 25s-30s (Confidence: 85%)"

### Stage 5: Auto-Cropping
- FFmpeg crops video around detected incident
- Saves as proof.mp4 in output folder

## Processing Times

| Video Length | Processing Time |
|---|---|
| 2 minutes | 10-15 seconds |
| 30 minutes | 3-5 minutes |
| 6 hours | 25-35 minutes |

## Models Used

- **LLaVA 1.5** - Vision-language model for semantic understanding
- **MOG2** - Background subtraction for motion detection
- **FFmpeg** - Video cropping

All models run locally. No cloud APIs.

## Caveats

1. Motion-only detection - static incidents may be missed
2. Confidence scores are model estimates, not ground truth
3. Timestamp precision ±1-2 seconds
4. Requires stable Ollama service during chat
5. First run downloads ~5GB of models

## Troubleshooting

**"CAPTURE command not found"**
- Close and reopen PowerShell
- Ensure install ran as Admin

**"Ollama connection failed"**
- Start Ollama: `ollama serve`
- In another terminal: `ollama pull llava:7b`

**"FFmpeg not found"**
- Install from https://ffmpeg.org/download.html
- Add to PATH or reinstall

## Project Structure

```
CAPTURE/
├── install.ps1          # Installation script
├── main.ps1             # Main CLI menu
├── banner.ps1           # ASCII banner
├── processor.ps1        # Video processing logic
├── chat.ps1             # Chat/query interface
└── README.md            # This file
```

## License

MIT - See LICENSE file

## Support

Issues? Check: https://github.com/ARIJIT-off/Capture/issues
