import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'overlay/recording_overlay.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/background_recording_service.dart';
import 'theme/app_theme.dart';

/// Entry point for the floating overlay isolate.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecordingOverlayApp());
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.gradientBottom,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
  unawaited(_initAppServices());
}

Future<void> _initAppServices() async {
  await AuthService.instance.init();
  try {
    await BackgroundRecordingService.instance.init();
  } catch (e, stack) {
    debugPrint('BackgroundRecordingService init failed: $e\n$stack');
  }

  // Listen for messages from the floating overlay (e.g. user taps Stop)
  FlutterOverlayWindow.overlayListener.listen((data) async {
    if (data == 'stop') {
      await BackgroundRecordingService.instance.stop();
      await FlutterOverlayWindow.closeOverlay();
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(BackgroundRecordingService.instance.resetAfterAppRestart());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Memory Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return DecoratedBox(
          decoration: AppTheme.pageBackgroundDecoration,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}
