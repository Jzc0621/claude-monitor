import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
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
  final display = await screenRetriever.getPrimaryDisplay();
  final screenSize = display.visibleSize ?? display.size;
  await windowManager.setPosition(Offset(
    screenSize.width - 450,
    20,
  ));

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
