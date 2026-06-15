import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/status_data.dart';

class StatusService extends ChangeNotifier {
  final String statusFilePath;
  final int port;
  StatusData? _currentStatus;
  StreamSubscription? _watcher;
  Timer? _pollTimer;
  DateTime? _lastLoad;
  bool _usePolling = false;
  HttpServer? _server;

  StatusService(this.statusFilePath, {this.port = 9876});

  StatusData? get currentStatus => _currentStatus;

  Future<void> start() async {
    if (_watcher != null || _pollTimer != null) return;
    await _loadStatus();
    _startServer();
    _startWatching();
  }

  // ─── HTTP Server (primary: instant push) ─────────────

  Future<void> _startServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      debugPrint('StatusService: HTTP server on port $port');
      _server!.listen(_handleRequest);
    } catch (e) {
      debugPrint('StatusService: HTTP server failed: $e');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method != 'POST' || request.uri.path != '/event') {
      request.response.statusCode = 404;
      request.response.close();
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      final event = jsonDecode(body) as Map<String, dynamic>;
      _applyEvent(event);
      _writeStatusFile();
      request.response.statusCode = 200;
    } catch (e) {
      debugPrint('StatusService: bad event: $e');
      request.response.statusCode = 400;
    }
    request.response.close();
  }

  void _applyEvent(Map<String, dynamic> event) {
    var s = _currentStatus ??
        StatusData.empty('sess_${DateTime.now().millisecondsSinceEpoch}');

    switch (event['event']) {
      case 'PreToolUse':
        s = _applyPreToolUse(s, event);
        break;
      case 'PostToolUse':
        s = _applyPostToolUse(s, event);
        break;
      case 'Stop':
        s.status = 'stopped';
        break;
    }

    if (s.startedAt != null) {
      final start = DateTime.tryParse(s.startedAt!) ?? DateTime.now();
      s.stats.elapsedSeconds = DateTime.now().difference(start).inSeconds;
    }
    _currentStatus = s;
    notifyListeners();
  }

  StatusData _applyPreToolUse(StatusData s, Map<String, dynamic> event) {
    final tool = event['tool_name'] as String? ?? '';
    s.status = 'running';

    final detail = event['tool_input']?['file_path'] as String? ??
        event['tool_input']?['description'] as String? ??
        event['tool_input']?['pattern'] as String? ??
        event['tool_input']?['command'] as String? ??
        '';

    s.currentAction = CurrentAction(
      type: _toolType(tool),
      detail: detail.length > 100 ? '${detail.substring(0, 100)}...' : detail,
    );

    final now = DateTime.now().toIso8601String().substring(11, 19);
    s.recentActivity.insert(
      0,
      ActivityItem(
        time: now,
        action: _toolAction(tool),
        file: event['tool_input']?['file_path'] as String?,
        detail: event['tool_input']?['description'] as String?,
      ),
    );
    if (s.recentActivity.length > 50) {
      s.recentActivity = s.recentActivity.sublist(0, 50);
    }

    return s;
  }

  StatusData _applyPostToolUse(StatusData s, Map<String, dynamic> event) {
    final tool = event['tool_name'] as String? ?? '';
    switch (tool) {
      case 'Read':
        s.stats.readCount++;
        break;
      case 'Write':
      case 'Edit':
        s.stats.editCount++;
        break;
      case 'Bash':
        s.stats.commandCount++;
        break;
    }

    final output = event['tool_output'] as String? ?? '';
    if (output.toLowerCase().contains('error') ||
        output.toLowerCase().contains('fail')) {
      s.stats.errorCount++;
      s.errors.add('$tool: ${output.length > 100 ? output.substring(0, 100) : output}');
      if (s.errors.length > 20) s.errors = s.errors.sublist(s.errors.length - 20);
    }

    final thinking = event['thinking'] as String?;
    if (thinking != null && thinking.isNotEmpty) {
      s.thinking = thinking.length > 200 ? '${thinking.substring(0, 200)}...' : thinking;
    }

    s.currentAction = null;
    return s;
  }

  String _toolType(String tool) {
    switch (tool) {
      case 'Read':
        return 'reading';
      case 'Write':
      case 'Edit':
        return 'editing';
      case 'Bash':
        return 'running';
      case 'Grep':
      case 'Glob':
        return 'searching';
      case 'Agent':
        return 'thinking';
      default:
        return 'idle';
    }
  }

  String _toolAction(String tool) {
    switch (tool) {
      case 'Read':
        return 'read';
      case 'Write':
      case 'Edit':
        return 'edit';
      case 'Bash':
        return 'command';
      case 'Grep':
      case 'Glob':
        return 'search';
      default:
        return 'idle';
    }
  }

  // ─── File (backup: persistence & recovery) ──────────

  void _writeStatusFile() {
    if (_currentStatus == null) return;
    try {
      final tmp = File('$statusFilePath.tmp');
      tmp.writeAsStringSync(jsonEncode(_currentStatus!.toJson()));
      tmp.renameSync(statusFilePath);
    } catch (_) {}
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
    } catch (e) {
      debugPrint('StatusService: parse error: $e');
    }
  }

  Future<void> _debounceLoad() async {
    final now = DateTime.now();
    if (_lastLoad != null &&
        now.difference(_lastLoad!).inMilliseconds < 100) {
      return;
    }
    _lastLoad = now;
    await _loadStatus();
  }

  void _startWatching() {
    if (_usePolling) {
      _startPolling();
      return;
    }
    try {
      final dir = Directory(File(statusFilePath).parent.path);
      _watcher = dir.watch().listen(
        (event) {
          if (event.path == statusFilePath) _debounceLoad();
        },
        onError: (e) {
          debugPrint('StatusService: watcher error -> polling: $e');
          _usePolling = true;
          _watcher?.cancel();
          _watcher = null;
          _startPolling();
        },
      );
    } catch (e) {
      debugPrint('StatusService: watcher failed -> polling: $e');
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
    _server?.close();
    _watcher?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
