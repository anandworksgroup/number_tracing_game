import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_tracing_game/src/app.dart';
import 'package:number_tracing_game/src/audio.dart';
import 'package:number_tracing_game/src/digits.dart';
import 'package:number_tracing_game/src/progress.dart';
import 'package:number_tracing_game/src/screens/balloon_screen.dart';
import 'package:number_tracing_game/src/screens/count_screen.dart';
import 'package:number_tracing_game/src/trace_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Progress> pumpApp(WidgetTester tester, {Widget? home, Map<String, Object> saved = const {}}) async {
  Audio.enabled = false;
  SharedPreferences.setMockInitialValues(saved);
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final progress = await Progress.load();
  await tester.pumpWidget(
    home == null
        ? TraceApp(progress: progress)
        : ProgressScope(
            progress: progress,
            child: MaterialApp(home: home),
          ),
  );
  await tester.pump();
  return progress;
}

/// Lets a route push or pop finish (the new route is built offstage first).
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Finds widgets whose string key starts with [prefix].
Finder keyStartsWith(String prefix, {String? except}) => find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> && k.value.startsWith(prefix) && k.value != except;
});

/// Drags a finger along every stroke of the number on the board.
Future<void> traceBoard(WidgetTester tester, int n) async {
  final board = find.byKey(const Key('trace-board'));
  final origin = tester.getTopLeft(board);
  final layout = layoutNumber(n);
  final fit = fitLayout(tester.getSize(board), layout);
  Offset screen(Offset p) => origin + fit.offset + p * fit.scale;
  for (final stroke in layout.strokes) {
    final g = await tester.startGesture(screen(stroke.first));
    for (var i = 0; i < stroke.length; i += 3) {
      await g.moveTo(screen(stroke[i]));
    }
    await g.moveTo(screen(stroke.last));
    await g.up();
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('home shows saved stars and opens a number to trace', (tester) async {
    await pumpApp(tester, saved: {'trace123': '{"stars":{"1":3,"2":2},"trophies":1}'});
    expect(find.byKey(const Key('home-stars')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('home-stars'))).data, '6');

    await tester.tap(find.byKey(const Key('go-trace')));
    await settle(tester);
    expect(find.text('Pick a number'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tile-3')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('trace-title'))).data, '3 · three');

    await tester.tap(find.byKey(const Key('trace-next')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('trace-title'))).data, '4 · four');
  });

  testWidgets('tracing a number with a finger shows the reward and saves stars', (tester) async {
    final progress = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('go-trace')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tile-4')));
    await settle(tester);

    await traceBoard(tester, 4);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<Text>(find.byKey(const Key('reward-title'))).data, 'Four!');
    expect(progress.stars[4], 3);

    // The counting reward adds one object at a time.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('4'), findsWidgets);

    await tester.tap(find.byKey(const Key('reward-next')));
    await settle(tester);
    expect(find.byKey(const Key('reward-title')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('trace-title'))).data, '5 · five');
  });

  testWidgets('leaving the trace screen right after finishing shows no reward', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('go-trace')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tile-1')));
    await settle(tester);
    await traceBoard(tester, 1);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('reward-title')), findsNothing);
    expect(find.text('Pick a number'), findsOneWidget);
  });

  testWidgets('count game: count everything, then pick the right number', (tester) async {
    final progress = await pumpApp(tester, home: CountScreen(random: Random(7)));
    // Let the objects finish popping in.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 1));
    final objects = keyStartsWith('count-obj-');
    final n = objects.evaluate().length;
    expect(n, inInclusiveRange(1, 10));
    for (var i = 0; i < n; i++) {
      await tester.tap(find.byKey(Key('count-obj-$i')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500)); // answer bubbles pop in
    expect(find.text('How many?'), findsOneWidget);

    final wrong = keyStartsWith('option-', except: 'option-$n');
    await tester.tap(wrong.first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('reward-title')), findsNothing);

    await tester.tap(find.byKey(Key('option-$n')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('reward-title'))).data, 'Yes! $n!');
    expect(progress.trophies, 1);

    await tester.pump(const Duration(milliseconds: 500)); // popup finishes popping in
    await tester.tap(find.byKey(const Key('reward-next')));
    await settle(tester);
    expect(find.text('Tap each one to count!'), findsOneWidget);
  });

  testWidgets('balloon game: popping five target balloons wins', (tester) async {
    final progress = await pumpApp(tester, home: BalloonScreen(random: Random(3)));
    final target = tester.widget<Text>(find.byKey(const Key('pop-target'))).data!;
    var popped = 0;
    final tapped = <Key>{};
    for (var frame = 0; frame < 3000 && popped < goal; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (frame % 4 != 0) continue;
      final sky = tester.getRect(find.byKey(const Key('sky')));
      for (final e in keyStartsWith('balloon-$target-').evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        if (!tapped.contains(e.widget.key) && r.top > sky.top + 10 && r.top + 110 < sky.bottom) {
          tapped.add(e.widget.key!);
          await tester.tapAt(r.topLeft + const Offset(42, 45));
          popped++;
          break;
        }
      }
    }
    await settle(tester);
    expect(popped, goal);
    expect(tester.widget<Text>(find.byKey(const Key('reward-title'))).data, 'Super popping!');
    expect(progress.trophies, 1);
  });
}
