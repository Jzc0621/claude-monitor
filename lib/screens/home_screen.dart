import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
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
        if (data == null) return _buildWaiting();
        return _buildContent(data);
      },
    );
  }

  Widget _buildWaiting() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF58A6FF), Color(0xFF3FB950)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF58A6FF).withValues(alpha:0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('等待 Claude 连接...',
                style: TextStyle(
                    color: Color(0xFFF0F6FC),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            const Text('启动 VS Code 中的 Claude Code 后自动更新',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StatusData data) {
    final elapsed = _formatDuration(data.stats.elapsedSeconds);
    final isRunning = data.status == 'running';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          _TitleBar(status: data.status, elapsed: elapsed, isRunning: isRunning),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                if (data.currentAction != null)
                  _CurrentActionCard(action: data.currentAction!, isRunning: isRunning),
                if (data.errors.isNotEmpty) _ErrorList(errors: data.errors),
                if (data.todos.isNotEmpty) _TodoPanel(todos: data.todos),
                if (data.recentActivity.isNotEmpty)
                  _ActivityTimeline(activities: data.recentActivity),
                if (data.thinking != null && data.thinking!.isNotEmpty)
                  _ThinkingCard(thinking: data.thinking!),
                _StatsBar(stats: data.stats),
              ].map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: w,
                  )).toList(),
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

// ─── Title Bar ────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  final String status;
  final String elapsed;
  final bool isRunning;

  const _TitleBar(
      {required this.status, required this.elapsed, required this.isRunning});

  @override
  Widget build(BuildContext context) {
    final accent = isRunning
        ? const Color(0xFF3FB950)
        : status == 'stopped'
            ? const Color(0xFFF85149)
            : const Color(0xFFD29922);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF161B22),
            const Color(0xFF0D1117),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha:0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF58A6FF), Color(0xFF79C0FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF58A6FF).withValues(alpha:0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.monitor_heart,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('Claude Monitor',
              style: TextStyle(
                  color: Color(0xFFF0F6FC),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          const Spacer(),
          _PulseDot(color: accent, isRunning: isRunning),
          const SizedBox(width: 6),
          Text(
            '${status == 'running' ? '运行中' : status == 'stopped' ? '已停止' : '空闲'} · $elapsed',
            style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ));
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool isRunning;

  const _PulseDot({required this.color, required this.isRunning});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isRunning) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.isRunning && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRunning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha:widget.isRunning ? _animation.value : 1.0),
            boxShadow: widget.isRunning
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha:0.5 * _animation.value),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
        );
      },
    );
  }
}

// ─── Current Action Card ──────────────────────────────────

class _CurrentActionCard extends StatelessWidget {
  final CurrentAction action;
  final bool isRunning;

  const _CurrentActionCard(
      {required this.action, required this.isRunning});

  IconData _icon() {
    return switch (action.type) {
      'reading' => Icons.menu_book_rounded,
      'editing' => Icons.edit_rounded,
      'thinking' => Icons.psychology_rounded,
      'running' => Icons.terminal_rounded,
      'searching' => Icons.search_rounded,
      _ => Icons.circle_notifications_rounded,
    };
  }

  Color _color() {
    return switch (action.type) {
      'reading' => const Color(0xFF58A6FF),
      'editing' => const Color(0xFF3FB950),
      'thinking' => const Color(0xFFBC8CFF),
      'running' => const Color(0xFFF0883E),
      'searching' => const Color(0xFF58A6FF),
      _ => const Color(0xFF8B949E),
    };
  }

  String _label() {
    return switch (action.type) {
      'reading' => '正在读取文件',
      'editing' => '正在编辑代码',
      'thinking' => '正在思考分析',
      'running' => '正在执行命令',
      'searching' => '正在搜索代码',
      _ => '当前操作',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha:0.12),
            color.withValues(alpha:0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(),
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
                const SizedBox(height: 3),
                Text(action.detail,
                    style: const TextStyle(
                        color: Color(0xFFF0F6FC),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (isRunning)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Error List ───────────────────────────────────────────

class _ErrorList extends StatelessWidget {
  final List<String> errors;

  const _ErrorList({required this.errors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF85149).withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF85149).withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.error_outline, color: Color(0xFFF85149), size: 16),
            SizedBox(width: 6),
            Text('错误', style: TextStyle(color: Color(0xFFF85149), fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ...errors.map((e) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ', style: TextStyle(color: Color(0xFFF85149), fontSize: 10)),
                  Expanded(child: Text(e, style: const TextStyle(color: Color(0xFFFFA198), fontSize: 10))),
                ]),
              )),
        ],
      ),
    );
  }
}

// ─── Todo Panel ───────────────────────────────────────────

class _TodoPanel extends StatelessWidget {
  final List<TodoItem> todos;

  const _TodoPanel({required this.todos});

  @override
  Widget build(BuildContext context) {
    final completed = todos.where((t) => t.status == 'completed').length;
    final progress = todos.isEmpty ? 0.0 : completed / todos.length;
    final pct = (progress * 100).round();

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.checklist_rounded, color: Color(0xFF58A6FF), size: 16),
            const SizedBox(width: 6),
            const Text('任务进度',
                style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3FB950).withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3FB950).withValues(alpha:0.3)),
              ),
              child: Text('$pct%',
                  style: const TextStyle(color: Color(0xFF3FB950), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFF21262D),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3FB950)),
            ),
          ),
          const SizedBox(height: 8),
          ...todos.map((t) {
            final done = t.status == 'completed';
            final active = t.status == 'in_progress';
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(
                  done ? Icons.check_circle : active ? Icons.play_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: done
                      ? const Color(0xFF3FB950)
                      : active
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFF484F58),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(t.content,
                      style: TextStyle(
                          color: done
                              ? const Color(0xFF8B949E)
                              : active
                                  ? const Color(0xFFF0F6FC)
                                  : const Color(0xFF484F58),
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          decoration: done ? TextDecoration.lineThrough : null)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Activity Timeline ────────────────────────────────────

class _ActivityTimeline extends StatelessWidget {
  final List<ActivityItem> activities;

  const _ActivityTimeline({required this.activities});

  @override
  Widget build(BuildContext context) {
    final display =
        activities.length > 10 ? activities.sublist(0, 10) : activities;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.timeline_rounded, color: Color(0xFFF0883E), size: 16),
            SizedBox(width: 6),
            Text('最近活动', style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ...display.map((a) => _ActivityRow(item: a)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityItem item;

  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.action) {
      'read' => (Icons.menu_book, const Color(0xFF58A6FF)),
      'edit' => (Icons.edit, const Color(0xFF3FB950)),
      'command' => (Icons.terminal, const Color(0xFFF0883E)),
      'search' => (Icons.search, const Color(0xFF79C0FF)),
      'error' => (Icons.error, const Color(0xFFF85149)),
      _ => (Icons.circle, const Color(0xFF8B949E)),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        SizedBox(
          width: 50,
          child: Text(item.time,
              style: const TextStyle(color: Color(0xFF484F58), fontSize: 10, fontFamily: 'monospace')),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(item.file ?? item.detail ?? '',
              style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

// ─── Thinking Card ────────────────────────────────────────

class _ThinkingCard extends StatelessWidget {
  final String thinking;

  const _ThinkingCard({required this.thinking});

  @override
  Widget build(BuildContext context) {
    final display =
        thinking.length > 150 ? '${thinking.substring(0, 150)}...' : thinking;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.lightbulb_outline, color: Color(0xFFBC8CFF), size: 16),
            SizedBox(width: 6),
            Text('思考分析', style: TextStyle(color: Color(0xFFBC8CFF), fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(display,
              style: const TextStyle(
                  color: Color(0xFFA5ADB9),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Stats Bar ────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final Stats stats;

  const _StatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(icon: Icons.menu_book, label: '读取', count: stats.readCount, color: const Color(0xFF58A6FF)),
          _StatItem(icon: Icons.edit, label: '编辑', count: stats.editCount, color: const Color(0xFF3FB950)),
          _StatItem(icon: Icons.terminal, label: '命令', count: stats.commandCount, color: const Color(0xFFF0883E)),
          _StatItem(icon: Icons.error, label: '错误', count: stats.errorCount,
              color: const Color(0xFFF85149), highlight: stats.errorCount > 0),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool highlight;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha:highlight ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: highlight ? Border.all(color: color.withValues(alpha:0.5), width: 1) : null,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(height: 4),
      Text('$count',
          style: TextStyle(
              color: highlight ? color : const Color(0xFFF0F6FC),
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      Text(label,
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
    ]);
  }
}

// ─── Shared: Glass Card ───────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
