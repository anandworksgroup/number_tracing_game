import 'package:flutter/material.dart';

import 'progress.dart';
import 'screens/home_screen.dart';
import 'ui.dart';

/// Makes [Progress] available to every screen and rebuilds them when it changes.
class ProgressScope extends InheritedNotifier<Progress> {
  const ProgressScope({super.key, required Progress progress, required super.child}) : super(notifier: progress);

  static Progress of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ProgressScope>()!.notifier!;
}

class TraceApp extends StatelessWidget {
  const TraceApp({super.key, required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    return ProgressScope(
      progress: progress,
      child: MaterialApp(
        title: '123 Trace & Count',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Baloo2',
          colorScheme: ColorScheme.fromSeed(seedColor: purple),
          scaffoldBackgroundColor: skyTop,
          textTheme: const TextTheme().apply(bodyColor: ink, displayColor: ink),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

Route<T> route<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);
