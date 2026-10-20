import 'package:flutter/material.dart';

import 'src/app_state.dart';
import 'src/ui/theme.dart';
import 'src/ui/feedback.dart';
import 'src/ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(DodateApp(state: state));
}

class DodateApp extends StatefulWidget {
  const DodateApp({super.key, required this.state});

  final AppState state;

  @override
  State<DodateApp> createState() => _DodateAppState();
}

class _DodateAppState extends State<DodateApp> {
  // Re-plan when the app comes back, so a day that passed is rebalanced.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: widget.state.refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => MaterialApp(
        title: 'Dodate',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: switch (widget.state.theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        builder: (context, child) => AppFeedback(state: widget.state, child: child!),
        home: HomeShell(state: widget.state),
      ),
    );
  }
}
