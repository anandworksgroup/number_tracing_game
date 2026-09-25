import 'dart:math';

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
        builder: (context, child) => TabletScale(child: child!),
        home: const HomeScreen(),
      ),
    );
  }
}

Route<T> route<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

/// On tablets, lays the app out for a phone-sized screen and scales it up, so buttons,
/// numbers and objects fill the screen instead of looking tiny. Phones are unchanged.
class TabletScale extends StatelessWidget {
  const TabletScale({super.key, required this.child});
  final Widget child;

  /// Width, in logical pixels, that the layout is designed around.
  static const designWidth = 400.0;

  static double scaleFor(Size size) {
    final scale = size.shortestSide / designWidth;
    return scale < 1.2 ? 1 : min(scale, 2.2);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = scaleFor(mq.size);
    if (scale == 1) return child;
    return MediaQuery(
      data: mq.copyWith(
        size: mq.size / scale,
        padding: mq.padding / scale,
        viewPadding: mq.viewPadding / scale,
        viewInsets: mq.viewInsets / scale,
      ),
      child: FittedBox(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: mq.size / scale, child: child),
      ),
    );
  }
}
