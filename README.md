# 🧠 Claude Monitor

A real-time status monitor for Claude Code, built with Flutter. Displays what Claude is doing — editing files, running commands, updating tasks — in a sleek always-on-top desktop window.

<p align="center">
  <img src="docs/screenshot.png" alt="Claude Monitor Screenshot" width="440">
</p>

## ✨ Features

- **Live action feed** — see which file Claude is reading, editing, or searching in real time
- **Task progress** — visual progress bar with todo list, synced from Claude's `TodoWrite` calls
- **Activity timeline** — scrollable log of recent file operations with timestamps
- **Thinking insight** — peek at Claude's current reasoning (first 150 chars)
- **Stats dashboard** — read / edit / command / error counters at a glance
- **Always on top** — compact 440×680 window stays visible above other apps
- **Animated pulse** — green breathing indicator when Claude is actively working
- **Draggable** — grab the title bar to reposition anywhere on screen

## 🏗 How It Works

```
Claude Code (VS Code)  →  Hook Script (Node.js)  →  status.json  →  Flutter App
```

1. **Claude Code Hook** — a Node.js script registered in `~/.claude/settings.json` fires on every tool call (`PreToolUse` / `PostToolUse` / `Stop`)
2. **Shared JSON file** — the hook writes status updates atomically to `status.json`
3. **Flutter Desktop App** — watches the file for changes and renders a beautiful dark-theme UI

## 📦 Installation

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x+
- Windows 10/11 (macOS and Linux supported but untested)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed in VS Code

### Build from Source

```bash
# Clone
git clone https://github.com/Jzc0621/claude-monitor.git
cd claude-monitor

# Install dependencies
flutter pub get

# Build Windows executable
flutter build windows

# The exe is at:
# build/windows/x64/runner/Release/claude_monitor.exe
```

### Install the Hook

The Claude Code hook script (`status-hook.js`) lives at `~/.claude/hooks/status-hook.js`. Register it by adding this to `~/.claude/settings.json`:

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "node C:\\Users\\YOURNAME\\.claude\\hooks\\status-hook.js"
        }
      ]
    }
  ],
  "PostToolUse": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "node C:\\Users\\YOURNAME\\.claude\\hooks\\status-hook.js"
        }
      ]
    }
  ],
  "Stop": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "node C:\\Users\\YOURNAME\\.claude\\hooks\\status-hook.js"
        }
      ]
    }
  ]
}
```

**Important:** Update the path to match your home directory. If you want the `status.json` on a different drive, edit `STATUS_FILE` in `status-hook.js` and `statusFilePath` in `lib/main.dart`.

## 🚀 Usage

1. Launch `claude_monitor.exe` — a dark window appears in the top-right corner
2. Start using Claude Code in VS Code
3. Watch the monitor update in real time as Claude works

**Hotkeys** (in the terminal running `flutter run`):
- `r` — hot reload (UI changes)
- `R` — hot restart (full state reset)
- `q` — quit

## 🎨 Design

| Color | Hex | Usage |
|-------|-----|-------|
| Background | `#0D1117` | Main window background |
| Cards | `#161B22` | Glass-like content panels |
| Accent Blue | `#58A6FF` | Reading, progress, links |
| Success Green | `#3FB950` | Editing, completed tasks, running status |
| Purple | `#BC8CFF` | Thinking analysis |
| Orange | `#F0883E` | Commands, search |
| Error Red | `#F85149` | Errors and warnings |

## 📁 Project Structure

```
claude_monitor/
├── lib/
│   ├── main.dart                  # Entry point, window config
│   ├── models/
│   │   └── status_data.dart       # Data models with JSON serialization
│   ├── services/
│   │   └── status_service.dart    # File watcher + polling service
│   └── screens/
│       └── home_screen.dart       # Full UI with all panels
├── hooks/
│   └── status-hook.js             # Claude Code hook script
├── status/                        # Runtime status.json (gitignored)
├── windows/                       # Windows platform config
└── docs/                          # Design documents
```

## 🛠 Tech Stack

- **Flutter** (Dart) — cross-platform desktop UI
- **window_manager** — frameless, always-on-top window control
- **dart:io** — file system watching and polling
- **Node.js** — Claude Code hook script (zero dependencies)

## 📄 License

MIT © 2026 zc

## 🙋 FAQ

**Q: Why a desktop app instead of a VS Code extension?**  
A: A standalone window stays visible when you Alt+Tab away from VS Code. You can glance at Claude's progress without switching windows.

**Q: Does the hook slow down Claude?**  
A: No. The hook writes a tiny JSON file (~2KB) and exits immediately. Node.js startup adds ~50ms per call.

**Q: Can I customize what's shown?**  
A: Yes. Edit `lib/screens/home_screen.dart` to reorder or remove panels. The data models in `lib/models/status_data.dart` control what the hook captures.

**Q: Why is the window stuck in the top-right corner?**  
A: It's not — grab the title bar and drag it anywhere you like.
