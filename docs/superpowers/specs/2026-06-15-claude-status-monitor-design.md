# Claude Status Monitor — Design Spec

## Overview

A standalone Windows desktop application (Flutter) that displays Claude Code's real-time working status. Claude Code writes status events to a shared JSON file via a hook; the Flutter app watches that file and renders the information in a compact, always-on-top window.

## Architecture

```
VS Code (Claude Code Extension)
  │
  │ ToolUse / TodoWrite / Session events
  ▼
Hook Script (~/.claude/hooks/status-hook.js)
  │
  │ Write JSON
  ▼
status.json (D:\Tools\ClaudeMonitor\status\status.json)
  │
  │ File watcher (dart:io FileSystemEntity.watch)
  ▼
Flutter Desktop App (D:\Tools\ClaudeMonitor\)
  │
  ▼
Always-on-top window, 440×680
```

## File Locations

| Item | Path | Drive | Size |
|------|------|-------|------|
| Flutter project | `D:\Tools\ClaudeMonitor\` | D | ~500MB+ (with build) |
| status.json | `D:\Tools\ClaudeMonitor\status\status.json` | D | < 50KB |
| Hook script | `C:\Users\28476\.claude\hooks\status-hook.js` | C | < 5KB |
| Hook config | `C:\Users\28476\.claude\settings.json` (append) | C | < 1KB change |

## Component 1: Claude Code Hook

### Trigger Events

A Node.js script registered in `~/.claude/settings.json` hooks. Fires on:

- **PreToolUse** — captures which tool is about to be called (Read, Write, Edit, Bash, Grep, Glob, TodoWrite, Agent)
- **PostToolUse** — captures result (success/failure), updates counters
- **Stop** — marks session as ended

### status.json Schema

```json
{
  "sessionId": "abc123",
  "startedAt": "2026-06-15T12:00:00Z",
  "status": "running",
  "currentAction": {
    "type": "editing",
    "detail": "ppg_service.c:128",
    "startedAt": "2026-06-15T12:03:15Z"
  },
  "todos": [
    { "content": "分析项目结构", "status": "completed" },
    { "content": "添加PPG模块", "status": "in_progress" },
    { "content": "编写测试", "status": "pending" },
    { "content": "构建验证", "status": "pending" }
  ],
  "recentActivity": [
    { "time": "12:03:15", "action": "edit", "file": "ppg_service.c:128" },
    { "time": "12:03:08", "action": "read", "file": "ppg_service.h" },
    { "time": "12:02:55", "action": "command", "detail": "grep PPG_Open" }
  ],
  "thinking": "需要在 PPG_Open 之后添加错误检查...",
  "stats": {
    "readCount": 12,
    "editCount": 5,
    "commandCount": 3,
    "errorCount": 0,
    "elapsedSeconds": 154
  },
  "errors": []
}
```

### Hook Implementation Notes

- One hook script handles both PreToolUse and PostToolUse by reading `$CLAUDE_HOOK_EVENT` env var
- Writes atomically: write to `.tmp` then rename (prevents partial reads)
- Truncates `recentActivity` to last 50 entries
- Resets on session start (Stop event from previous session)
- Error-tolerant: hook failures must not interrupt Claude's operation

## Component 2: Flutter Desktop App

### Platform Targets

- Primary: Windows (win32)
- Future: macOS, Linux

### Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  window_manager: ^0.3.0    # always-on-top, window size/position
  file: ^7.0.0               # cross-platform file watching poll fallback
```

### Window Configuration

- Size: 440 × 680 px
- Always on top: true
- Start position: top-right corner of primary monitor
- Frameless with custom title bar (drag handle)
- Minimize / close buttons only

### UI Layout (Stacked Vertical)

```
┌─────────────────────────────────┐
│ 🧠 Claude Monitor    🟢 2m34s  │  ← Title bar + status indicator
├─────────────────────────────────┤
│ ✏️ 正在编辑                     │  ← Current action (large, prominent)
│    ppg_service.c:128            │
├─────────────────────────────────┤
│ 📋 任务进度          2/4 完成   │  ← Todo section
│ ████████░░░░░░░░  50%          │
│ ✅ 分析项目结构                  │
│ 🔄 添加PPG模块                   │
│ ⏳ 编写测试                      │
│ ⏳ 构建验证                      │
├─────────────────────────────────┤
│ 📜 最近活动                     │  ← Activity timeline
│ 12:03:15 ✏️ ppg_service.c:128  │
│ 12:03:08 📖 ppg_service.h      │
│ 12:02:55 🔧 grep PPG_Open      │
├─────────────────────────────────┤
│ 🧠 思考                         │  ← Thinking summary
│ 需要在PPG_Open之后添加错误检查... │
├─────────────────────────────────┤
│ 📖 12  ✏️ 5  🔧 3  ⚠️ 0      │  ← Stats bar
│ 读取    编辑   命令   错误       │
└─────────────────────────────────┘
```

### Color Scheme

- Background: `#1E1E2E` (dark, low eye strain)
- Cards/Sections: `#2A2A3C` with 1px `#3A3A50` border
- Accent: `#89B4FA` (blue) for active state
- Success: `#A6E3A1` (green)
- Warning: `#F9E2AF` (yellow)
- Text: `#CDD6F4` (light gray) primary, `#6C7086` secondary

### State Management

- Single `StatusProvider` — reads `status.json` on startup, listens for changes via `FileSystemEntity.watch()`
- If `watch()` is unreliable on Windows, fall back to 500ms polling via `dart:io File.lastModifiedSync()`
- `ChangeNotifier` notifies widget tree on each update
- Smooth transitions: `AnimatedContainer` / `AnimatedOpacity` for status changes

### Refresh Strategy

1. Primary: `FileSystemEntity.watch()` on `status.json` parent directory
2. Fallback: Timer-based 500ms polling, checking `File.lastModifiedSync()`
3. Debounce: coalesce rapid changes within 100ms window

## Error Handling

- status.json missing → show "等待 Claude 连接..." placeholder
- status.json malformed → show "⚠️ 数据解析错误" + last valid state
- File watcher fails → auto-switch to polling
- Hook script error → logged to `status/error.log`, does not interrupt Claude

## Future Enhancements (Out of Scope for v1)

- Multiple session history view
- Token cost estimation
- Desktop notifications on task completion
- System tray minimize to tray
- Theme customization

## Development Setup

```bash
cd D:\Tools\ClaudeMonitor
flutter create --platforms=windows .
# Overwrite lib/main.dart with app code
flutter pub add window_manager file
flutter run -d windows
```
