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

    return Container(
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
        ? '${thinking.substring(0, 120)}...'
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
