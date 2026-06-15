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
    if (_watcher != null || _pollTimer != null) return;
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
    } catch (e) {
      // Keep last valid state on parse error
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
          if (event.path == statusFilePath) {
            _debounceLoad();
          }
        },
        onError: (e) {
          debugPrint(
              'StatusService: watcher error, falling back to polling: $e');
          _usePolling = true;
          _watcher?.cancel();
          _watcher = null;
          _startPolling();
        },
      );
    } catch (e) {
      debugPrint(
          'StatusService: failed to start watcher, falling back to polling: $e');
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
