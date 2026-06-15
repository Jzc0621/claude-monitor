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

  const Stats({
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
