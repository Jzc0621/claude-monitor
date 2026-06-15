# Claude Status Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real-time Claude Code status monitor with a Flutter desktop window + a Claude Code hook that writes status events to a shared JSON file.

**Architecture:** Claude Code fires hooks (PreToolUse/PostToolUse/Stop) → a Node.js hook script updates `status.json` atomically → the Flutter app watches the file and renders a stacked dark-theme UI in a 440×680 always-on-top window.

**Tech Stack:** Flutter (Windows), `window_manager` package, Node.js (hook script), `dart:io` file watching

**File Map:**
- Create: `D:\Tools\ClaudeMonitor\lib\main.dart` — window init + runApp
- Create: `D:\Tools\ClaudeMonitor\lib\models\status_data.dart` — data classes with JSON parsing
- Create: `D:\Tools\ClaudeMonitor\lib\services\status_service.dart` — file watch + polling + ChangeNotifier
- Create: `D:\Tools\ClaudeMonitor\lib\screens\home_screen.dart` — full UI
- Create: `C:\Users\28476\.claude\hooks\status-hook.js` — hook script
- Modify: `C:\Users\28476\.claude\settings.json` — register hooks
- Modify: `D:\Tools\ClaudeMonitor\pubspec.yaml` — add window_manager dependency

---

### Task 1: Create Flutter Project Scaffold

**Files:**
- Create: `D:\Tools\ClaudeMonitor\` (flutter create)
- Modify: `D:\Tools\ClaudeMonitor\pubspec.yaml`

- [ ] **Step 1: Create Flutter Windows project**

Run:
```bash
flutter create --platforms=windows D:\Tools\ClaudeMonitor
```
Expected: Creates Flutter project with `windows/`, `lib/main.dart`, etc.

- [ ] **Step 2: Add window_manager dependency**

Read existing `D:\Tools\ClaudeMonitor\pubspec.yaml`, then edit the dependencies section.

```yaml
dependencies:
  flutter:
    sdk: flutter
  window_manager: ^0.3.0
```

- [ ] **Step 3: Run pub get to verify**

Run:
```bash
cd D:\Tools\ClaudeMonitor && flutter pub get
```
Expected: exits 0, no errors.

- [ ] **Step 4: Create empty directory structure**

Run:
```bash
mkdir -p D:\Tools\ClaudeMonitor\lib\models D:\Tools\ClaudeMonitor\lib\services D:\Tools\ClaudeMonitor\lib\screens D:\Tools\ClaudeMonitor\status
```
Expected: directories created.

- [ ] **Step 5: Commit**

```bash
cd D:\Tools\ClaudeMonitor && git init && git add -A && git commit -m "feat: scaffold Flutter Windows project with window_manager"
```

---

### Task 2: Data Models

**Files:**
- Create: `D:\Tools\ClaudeMonitor\lib\models\status_data.dart`

- [ ] **Step 1: Write status_data.dart with all model classes**

```dart
import 'dart:convert';

class CurrentAction {
  final String type;   // reading, editing, thinking, running, searching, idle
  final String detail;
  final String? startedAt;

  CurrentAction({required this.type, required this.detail, this.startedAt});

  factory CurrentAction.fromJson(Map<String, dynamic> json) {
    return CurrentAction(
      type: json['type'] as String? ?? 'idle',
      detail: json['detail'] as String? ?? '',
      startedAt: json['startedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'detail': detail,
        if (startedAt != null) 'startedAt': startedAt,
      };
}

class TodoItem {
  final String content;
  final String status; // pending, in_progress, completed

  TodoItem({required this.content, required this.status});

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'status': status,
      };
}

class ActivityItem {
  final String time;
  final String action; // read, edit, command, search, error
  final String? file;
  final String? detail;

  ActivityItem({required this.time, required this.action, this.file, this.detail});

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      time: json['time'] as String? ?? '',
      action: json['action'] as String? ?? '',
      file: json['file'] as String?,
      detail: json['detail'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'action': action,
        if (file != null) 'file': file,
        if (detail != null) 'detail': detail,
      };
}

class Stats {
  final int readCount;
  final int editCount;
  final int commandCount;
  final int errorCount;
  final int elapsedSeconds;

  Stats({
    this.readCount = 0,
    this.editCount = 0,
    this.commandCount = 0,
    this.errorCount = 0,
    this.elapsedSeconds = 0,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      readCount: json['readCount'] as int? ?? 0,
      editCount: json['editCount'] as int? ?? 0,
      commandCount: json['commandCount'] as int? ?? 0,
      errorCount: json['errorCount'] as int? ?? 0,
      elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'readCount': readCount,
        'editCount': editCount,
        'commandCount': commandCount,
        'errorCount': errorCount,
        'elapsedSeconds': elapsedSeconds,
      };
}

class StatusData {
  final String sessionId;
  final String? startedAt;
  final String status; // running, idle, stopped
  final CurrentAction? currentAction;
  final List<TodoItem> todos;
  final List<ActivityItem> recentActivity;
  final String? thinking;
  final Stats stats;
  final List<String> errors;

  StatusData({
    required this.sessionId,
    this.startedAt,
    this.status = 'running',
    this.currentAction,
    this.todos = const [],
    this.recentActivity = const [],
    this.thinking,
    this.stats = const Stats(),
    this.errors = const [],
  });

  factory StatusData.fromJson(Map<String, dynamic> json) {
    return StatusData(
      sessionId: json['sessionId'] as String? ?? '',
      startedAt: json['startedAt'] as String?,
      status: json['status'] as String? ?? 'running',
      currentAction: json['currentAction'] != null
          ? CurrentAction.fromJson(json['currentAction'] as Map<String, dynamic>)
          : null,
      todos: (json['todos'] as List<dynamic>?)
              ?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentActivity: (json['recentActivity'] as List<dynamic>?)
              ?.map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      thinking: json['thinking'] as String?,
      stats: json['stats'] != null
          ? Stats.fromJson(json['stats'] as Map<String, dynamic>)
          : const Stats(),
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        if (startedAt != null) 'startedAt': startedAt,
        'status': status,
        if (currentAction != null) 'currentAction': currentAction!.toJson(),
        'todos': todos.map((e) => e.toJson()).toList(),
        'recentActivity': recentActivity.map((e) => e.toJson()).toList(),
        if (thinking != null) 'thinking': thinking,
        'stats': stats.toJson(),
        'errors': errors,
      };

  static StatusData empty(String sessionId) {
    return StatusData(
      sessionId: sessionId,
      startedAt: DateTime.now().toIso8601String(),
      status: 'idle',
      stats: Stats(elapsedSeconds: 0),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
cd D:\Tools\ClaudeMonitor && flutter analyze lib/models/status_data.dart
```
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
cd D:\Tools\ClaudeMonitor && git add lib/models/status_data.dart && git commit -m "feat: add status data models with JSON serialization"
```

---

### Task 3: Status Service (File Watch + Polling)

**Files:**
- Create: `D:\Tools\ClaudeMonitor\lib\services\status_service.dart`

- [ ] **Step 1: Write status_service.dart**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/status_data.dart';

class StatusService extends ChangeNotifier {
  final String statusFilePath;
  StatusData? _currentStatus;
  StreamSubscription? _watcher;
  Timer? _pollTimer;
  DateTime? _lastLoad;
  bool _usePolling = false;

  StatusService(this.statusFilePath);

  StatusData? get currentStatus => _currentStatus;

  Future<void> start() async {
    await _loadStatus();
    _startWatching();
  }

  Future<void> _loadStatus() async {
    final file = File(statusFilePath);
    if (!await file.exists()) return;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;
      final json = jsonDecode(content) as Map<String, dynamic>;
      _currentStatus = StatusData.fromJson(json);
      notifyListeners();
    } catch (_) {
      // Keep last valid state on parse error
    }
  }

  void _debounceLoad() {
    final now = DateTime.now();
    if (_lastLoad != null &&
        now.difference(_lastLoad!).inMilliseconds < 100) return;
    _lastLoad = now;
    _loadStatus();
  }

  void _startWatching() {
    if (_usePolling) {
      _startPolling();
      return;
    }
    try {
      final dir = Directory(File(statusFilePath).parent.path);
      _watcher = dir.watch().listen((event) {
        if (event.path == statusFilePath) {
          _debounceLoad();
        }
      });
    } catch (_) {
      _usePolling = true;
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _debounceLoad(),
    );
  }

  @override
  void dispose() {
    _watcher?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
cd D:\Tools\ClaudeMonitor && flutter analyze lib/services/status_service.dart
```
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
cd D:\Tools\ClaudeMonitor && git add lib/services/status_service.dart && git commit -m "feat: add status service with file watch and polling fallback"
```

---

### Task 4: Home Screen UI

**Files:**
- Create: `D:\Tools\ClaudeMonitor\lib\screens\home_screen.dart`

- [ ] **Step 1: Write home_screen.dart with all UI sections**

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/status_data.dart';
import '../services/status_service.dart';

class HomeScreen extends StatelessWidget {
  final StatusService statusService;

  const HomeScreen({super.key, required this.statusService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: statusService,
      builder: (context, _) {
        final data = statusService.currentStatus;
        if (data == null) {
          return _buildWaiting();
        }
        return _buildContent(data);
      },
    );
  }

  Widget _buildWaiting() {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty,
                size: 48, color: Color(0xFF6C7086)),
            const SizedBox(height: 16),
            const Text(
              '等待 Claude 连接...',
              style: TextStyle(
                color: Color(0xFFCDD6F4),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '启动 VS Code 中的 Claude Code 后自动更新',
              style: TextStyle(
                color: const Color(0xFFCDD6F4).withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StatusData data) {
    final elapsed = _formatDuration(data.stats.elapsedSeconds);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: Column(
        children: [
          _TitleBar(status: data.status, elapsed: elapsed),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.currentAction != null)
                    _CurrentActionCard(action: data.currentAction!),
                  if (data.errors.isNotEmpty) _ErrorList(errors: data.errors),
                  if (data.todos.isNotEmpty)
                    _TodoPanel(todos: data.todos),
                  if (data.recentActivity.isNotEmpty)
                    _ActivityTimeline(activities: data.recentActivity),
                  if (data.thinking != null && data.thinking!.isNotEmpty)
                    _ThinkingCard(thinking: data.thinking!),
                  _StatsBar(stats: data.stats),
                ].map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: w,
                    )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _TitleBar extends StatelessWidget {
  final String status;
  final String elapsed;

  const _TitleBar({required this.status, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'running'
        ? const Color(0xFFA6E3A1)
        : status == 'stopped'
            ? const Color(0xFFF38BA8)
            : const Color(0xFFF9E2AF);
    final statusText = status == 'running'
        ? '运行中'
        : status == 'stopped'
            ? '已停止'
            : '空闲';

    return GestureDetector(
      onPanStart: (_) {},
      onPanUpdate: (details) {
        // Window drag will be handled by window_manager
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF181825),
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            Text('🧠 Claude Monitor',
                style: TextStyle(
                    color: const Color(0xFFCDD6F4).withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text('$statusText · $elapsed',
                style: const TextStyle(
                    color: Color(0xFF6C7086), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _CurrentActionCard extends StatelessWidget {
  final CurrentAction action;

  const _CurrentActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final icon = switch (action.type) {
      'reading' => '📖',
      'editing' => '✏️',
      'thinking' => '🧠',
      'running' => '🔧',
      'searching' => '🔍',
      _ => '📌',
    };
    final label = switch (action.type) {
      'reading' => '正在读取',
      'editing' => '正在编辑',
      'thinking' => '正在思考',
      'running' => '正在执行',
      'searching' => '正在搜索',
      _ => '当前操作',
    };

    return _Card(
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF89B4FA),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(action.detail,
                    style: const TextStyle(
                        color: Color(0xFFCDD6F4), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoPanel extends StatelessWidget {
  final List<TodoItem> todos;

  const _TodoPanel({required this.todos});

  @override
  Widget build(BuildContext context) {
    final completed =
        todos.where((t) => t.status == 'completed').length;
    final inProgress =
        todos.where((t) => t.status == 'in_progress').length;
    final progress = todos.isEmpty ? 0.0 : completed / todos.length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📋 任务进度',
                  style: TextStyle(
                      color: Color(0xFF89B4FA),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$completed/${todos.length} 完成',
                  style: const TextStyle(
                      color: Color(0xFF6C7086), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFF313244),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFA6E3A1)),
            ),
          ),
          const SizedBox(height: 6),
          ...todos.map((t) {
            final icon = t.status == 'completed'
                ? '✅'
                : t.status == 'in_progress'
                    ? '🔄'
                    : '⏳';
            final color = t.status == 'completed'
                ? const Color(0xFF6C7086)
                : t.status == 'in_progress'
                    ? const Color(0xFF89B4FA)
                    : const Color(0xFF45475A);
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('$icon ${t.content}',
                  style: TextStyle(color: color, fontSize: 10)),
            );
          }),
        ],
      ),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final List<ActivityItem> activities;

  const _ActivityTimeline({required this.activities});

  @override
  Widget build(BuildContext context) {
    final display = activities.length > 6
        ? activities.sublist(activities.length - 6)
        : activities;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📜 最近活动',
              style: TextStyle(
                  color: Color(0xFF89B4FA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...display.map((a) {
            final icon = switch (a.action) {
              'read' => '📖',
              'edit' => '✏️',
              'command' => '🔧',
              'search' => '🔍',
              'error' => '⚠️',
              _ => '•',
            };
            final desc = a.file ?? a.detail ?? '';
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${a.time}  $icon  $desc',
                  style: const TextStyle(
                      color: Color(0xFFA6ADC8), fontSize: 10)),
            );
          }),
        ],
      ),
    );
  }
}

class _ThinkingCard extends StatelessWidget {
  final String thinking;

  const _ThinkingCard({required this.thinking});

  @override
  Widget build(BuildContext context) {
    final display = thinking.length > 120
        ? '${thinking.substring(0, max(0, 120))}...'
        : thinking;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧠 思考',
              style: TextStyle(
                  color: Color(0xFF89B4FA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(display,
              style: TextStyle(
                  color: const Color(0xFFCDD6F4).withOpacity(0.6),
                  fontSize: 10,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final Stats stats;

  const _StatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(icon: '📖', label: '读取', count: stats.readCount),
          _StatItem(icon: '✏️', label: '编辑', count: stats.editCount),
          _StatItem(icon: '🔧', label: '命令', count: stats.commandCount),
          _StatItem(icon: '⚠️', label: '错误', count: stats.errorCount,
              isError: stats.errorCount > 0),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final bool isError;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text('$count',
            style: TextStyle(
                color: isError && count > 0
                    ? const Color(0xFFF38BA8)
                    : const Color(0xFFCDD6F4),
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6C7086), fontSize: 9)),
      ],
    );
  }
}

class _ErrorList extends StatelessWidget {
  final List<String> errors;

  const _ErrorList({required this.errors});

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: const Color(0xFF2A1A1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⚠️',
                  style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
              Text('错误',
                  style: TextStyle(
                      color: Color(0xFFF38BA8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ...errors.map((e) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(e,
                    style: const TextStyle(
                        color: Color(0xFFF38BA8), fontSize: 10)),
              )),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;

  const _Card({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF2A2A3C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A50), width: 1),
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
cd D:\Tools\ClaudeMonitor && flutter analyze lib/screens/home_screen.dart
```
Expected: No issues found. (May need to add `import 'package:flutter/widgets.dart';` if AnimatedBuilder is not found — it's from `package:flutter/widgets.dart` which is re-exported by `material.dart`)

- [ ] **Step 3: Commit**

```bash
cd D:\Tools\ClaudeMonitor && git add lib/screens/home_screen.dart && git commit -m "feat: add home screen UI with all status panels"
```

---

### Task 5: Main Entry Point + Window Configuration

**Files:**
- Modify: `D:\Tools\ClaudeMonitor\lib\main.dart` (overwrite default)

- [ ] **Step 1: Write main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/status_service.dart';
import 'screens/home_screen.dart';

const statusFilePath = 'D:\\Tools\\ClaudeMonitor\\status\\status.json';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size: const Size(440, 680),
    minimumSize: const Size(320, 400),
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Move to top-right corner
  final primaryScreen = await windowManager.getPrimaryScreen();
  if (primaryScreen != null) {
    final screenSize = primaryScreen.visiblePosition.size;
    await windowManager.setPosition(Offset(
      screenSize.width - 450,
      20,
    ));
  }

  final statusService = StatusService(statusFilePath);
  await statusService.start();

  runApp(ClaudeMonitorApp(statusService: statusService));
}

class ClaudeMonitorApp extends StatelessWidget {
  final StatusService statusService;

  const ClaudeMonitorApp({super.key, required this.statusService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Claude Monitor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      ),
      home: HomeScreen(statusService: statusService),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
cd D:\Tools\ClaudeMonitor && flutter analyze lib/main.dart
```
Expected: No issues found.

- [ ] **Step 3: Build Windows exe to verify everything links**

Run:
```bash
cd D:\Tools\ClaudeMonitor && flutter build windows
```
Expected: Build successful, exe at `build/windows/x64/runner/Release/`.

- [ ] **Step 4: Commit**

```bash
cd D:\Tools\ClaudeMonitor && git add lib/main.dart && git commit -m "feat: add main entry with window manager config"
```

---

### Task 6: Claude Code Status Hook Script

**Files:**
- Create: `C:\Users\28476\.claude\hooks\status-hook.js`

- [ ] **Step 1: Create hooks directory**

Run:
```bash
mkdir -p "C:\Users\28476\.claude\hooks"
```

- [ ] **Step 2: Write status-hook.js**

```javascript
const fs = require('fs');
const path = require('path');

const STATUS_FILE = 'D:\\Tools\\ClaudeMonitor\\status\\status.json';
const STATUS_DIR = path.dirname(STATUS_FILE);

function main() {
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { input += chunk; });
  process.stdin.on('end', () => {
    try {
      const event = JSON.parse(input);
      processEvent(event);
    } catch (e) {
      // Never block Claude
      logError('parse error: ' + e.message);
    }
  });
}

function processEvent(event) {
  let status = readStatus();

  switch (event.event) {
    case 'PreToolUse':
      status = applyPreToolUse(status, event);
      break;
    case 'PostToolUse':
      status = applyPostToolUse(status, event);
      break;
    case 'Stop':
      status.status = 'stopped';
      break;
  }

  status.stats.elapsedSeconds = calcElapsed(status);
  writeStatus(status);
}

function applyPreToolUse(status, event) {
  const tool = event.tool_name || '';
  status.status = 'running';

  switch (tool) {
    case 'Read':
      status.currentAction = { type: 'reading', detail: event.tool_input?.file_path || '' };
      break;
    case 'Write':
    case 'Edit':
      status.currentAction = { type: 'editing', detail: event.tool_input?.file_path || '' };
      break;
    case 'Bash':
      status.currentAction = { type: 'running', detail: (event.tool_input?.description || event.tool_input?.command || '').substring(0, 100) };
      break;
    case 'Grep':
    case 'Glob':
      status.currentAction = { type: 'searching', detail: event.tool_input?.pattern || '' };
      break;
    case 'TodoWrite':
      if (event.tool_input?.todos) {
        status.todos = event.tool_input.todos.map(t => ({
          content: t.content || '',
          status: t.status || 'pending'
        }));
      }
      status.currentAction = { type: 'editing', detail: '更新任务列表' };
      break;
    case 'Agent':
      status.currentAction = { type: 'thinking', detail: event.tool_input?.description || '启动子代理' };
      break;
    default:
      status.currentAction = { type: 'idle', detail: tool };
  }

  const now = new Date().toLocaleTimeString('zh-CN', { hour12: false });
  const actItem = {
    time: now,
    action: toolToAction(tool),
    file: event.tool_input?.file_path || undefined,
    detail: event.tool_input?.description || undefined,
  };
  status.recentActivity.unshift(actItem);
  if (status.recentActivity.length > 50) {
    status.recentActivity = status.recentActivity.slice(0, 50);
  }

  return status;
}

function applyPostToolUse(status, event) {
  const tool = event.tool_name || '';

  // Update counters
  switch (tool) {
    case 'Read':
      status.stats.readCount = (status.stats.readCount || 0) + 1;
      break;
    case 'Write':
    case 'Edit':
      status.stats.editCount = (status.stats.editCount || 0) + 1;
      break;
    case 'Bash':
      status.stats.commandCount = (status.stats.commandCount || 0) + 1;
      break;
  }

  // Check for errors
  if (event.tool_output && typeof event.tool_output === 'string' && event.tool_output.toLowerCase().includes('error')) {
    status.stats.errorCount = (status.stats.errorCount || 0) + 1;
    status.errors.push(`${tool}: ${event.tool_output.substring(0, 100)}`);
    if (status.errors.length > 20) {
      status.errors = status.errors.slice(-20);
    }
  }

  // Check thinking content
  if (event.thinking && typeof event.thinking === 'string') {
    status.thinking = event.thinking.substring(0, 200);
  }

  status.currentAction = null;
  return status;
}

function toolToAction(tool) {
  switch (tool) {
    case 'Read': return 'read';
    case 'Write':
    case 'Edit': return 'edit';
    case 'Bash': return 'command';
    case 'Grep':
    case 'Glob': return 'search';
    default: return 'idle';
  }
}

function readStatus() {
  try {
    if (fs.existsSync(STATUS_FILE)) {
      const raw = fs.readFileSync(STATUS_FILE, 'utf8');
      if (raw.trim()) {
        return JSON.parse(raw);
      }
    }
  } catch (_) {}

  return {
    sessionId: 'sess_' + Date.now(),
    startedAt: new Date().toISOString(),
    status: 'idle',
    currentAction: null,
    todos: [],
    recentActivity: [],
    thinking: null,
    stats: { readCount: 0, editCount: 0, commandCount: 0, errorCount: 0, elapsedSeconds: 0 },
    errors: [],
  };
}

function writeStatus(status) {
  try {
    if (!fs.existsSync(STATUS_DIR)) {
      fs.mkdirSync(STATUS_DIR, { recursive: true });
    }
    const tmp = STATUS_FILE + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(status, null, 2), 'utf8');
    fs.renameSync(tmp, STATUS_FILE);
  } catch (_) {}
}

function calcElapsed(status) {
  if (!status.startedAt) return 0;
  const start = new Date(status.startedAt).getTime();
  const now = Date.now();
  return Math.max(0, Math.floor((now - start) / 1000));
}

function logError(msg) {
  try {
    const logFile = path.join(STATUS_DIR, 'error.log');
    fs.appendFileSync(logFile, `[${new Date().toISOString()}] ${msg}\n`);
  } catch (_) {}
}

main();
```

- [ ] **Step 3: Test script can parse a mock event**

Run:
```bash
echo '{"event":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"test.txt"}}' | node "C:\Users\28476\.claude\hooks\status-hook.js"
```
Expected: Creates `D:\Tools\ClaudeMonitor\status\status.json` with currentAction.type="reading". Check:
```bash
node -e "const s=require('D:/Tools/ClaudeMonitor/status/status.json'); console.log(s.currentAction.type, s.status);"
```
Expected output: `reading running`

- [ ] **Step 4: Commit**

```bash
cd C:\Users\28476\.claude\hooks && git init && git add status-hook.js && git commit -m "feat: add Claude Code status hook script"
```

---

### Task 7: Register Hook in Claude Code Settings

**Files:**
- Read: `C:\Users\28476\.claude\settings.json`
- Modify: `C:\Users\28476\.claude\settings.json` (add hooks section)

- [ ] **Step 1: Read current settings**

Run:
```bash
type "C:\Users\28476\.claude\settings.json"
```

- [ ] **Step 2: Add hooks configuration**

Add the `hooks` key to settings.json:

```json
{
    "workbench.colorTheme": "GitHub Light",
    "workbench.iconTheme": "vscode-icons",
    "claudeCode.preferredLocation": "panel",
    "vsicons.dontShowNewVersionMessage": true,
    "dart.flutterSdkPath": "D:\\Tools\\Flutter\\flutter",
    "claudeCode.apiKey": "sk-e1900db6e22b49178e07f25e9f3f5c14",
    "claudeCode.baseUrl": "https://api.deepseek.com/anthropic",
    "claudeCode.model": "deepseek-v4-pro",
    "hooks": {
        "PreToolUse": [
            { "command": "node C:\\Users\\28476\\.claude\\hooks\\status-hook.js" }
        ],
        "PostToolUse": [
            { "command": "node C:\\Users\\28476\\.claude\\hooks\\status-hook.js" }
        ],
        "Stop": [
            { "command": "node C:\\Users\\28476\\.claude\\hooks\\status-hook.js" }
        ]
    }
}
```

- [ ] **Step 3: Verify JSON is valid**

Run:
```bash
node -e "JSON.parse(require('fs').readFileSync('C:/Users/28476/.claude/settings.json','utf8')); console.log('OK')"
```
Expected: `OK`

---

### Task 8: Integration Test

- [ ] **Step 1: Launch the Flutter app**

Run:
```bash
cd D:\Tools\ClaudeMonitor && flutter run -d windows
```
Expected: Window appears at top-right corner, 440×680, dark theme, showing "等待 Claude 连接..."

- [ ] **Step 2: Simulate Claude events with the hook script**

```bash
echo '{"event":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"ppg_service.c:128"}}' | node "C:\Users\28476\.claude\hooks\status-hook.js"
```
Check the Flutter window updates to show "✏️ 正在编辑 · ppg_service.c:128"

- [ ] **Step 3: Simulate a PostToolUse event**

```bash
echo '{"event":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"ppg_service.c:128"}}' | node "C:\Users\28476\.claude\hooks\status-hook.js"
```
Check the Flutter window: edit count increments, current action clears.

- [ ] **Step 4: Simulate a TodoWrite event**

```bash
echo '{"event":"PreToolUse","tool_name":"TodoWrite","tool_input":{"todos":[{"content":"分析项目","status":"completed"},{"content":"添加PPG模块","status":"in_progress"},{"content":"编写测试","status":"pending"}]}}' | node "C:\Users\28476\.claude\hooks\status-hook.js"
```
Check the Flutter window: todo panel shows 3 items with progress bar.

- [ ] **Step 5: Simulate Stop event**

```bash
echo '{"event":"Stop"}' | node "C:\Users\28476\.claude\hooks\status-hook.js"
```
Check the Flutter window: status indicator turns red, shows "已停止".

- [ ] **Step 6: Verify error resilience**

```bash
echo 'invalid json' | node "C:\Users\28476\.claude\hooks\status-hook.js"
```
Expected: Hook exits cleanly (no crash), status.json unchanged.

---

### Task 9: Add .gitignore for D drive project

**Files:**
- Create: `D:\Tools\ClaudeMonitor\.gitignore`

- [ ] **Step 1: Write .gitignore**

```
build/
.dart_tool/
.packages
.flutter-plugins
.flutter-plugins-dependencies
*.iml
.superpowers/
status.json
status.json.tmp
status/error.log
```

- [ ] **Step 2: Commit**

```bash
cd D:\Tools\ClaudeMonitor && git add .gitignore && git commit -m "chore: add .gitignore"
```
