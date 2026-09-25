// Parents area behind a parental gate (Google Play Families policy): a
// multiplication question young children can't answer, then privacy info and
// the reset button. Nothing here links out of the app.
import 'dart:math';

import 'package:flutter/material.dart';

import 'app.dart';
import 'ui.dart';

const privacySummary =
    'This app has no ads, no in-app purchases and no accounts. It does not collect, '
    'store or share any personal information, and it works without an internet connection. '
    'Stars and settings are saved only on this device and are removed when the app is uninstalled. '
    'Numbers are spoken by the text-to-speech engine built into the device.';

Future<void> openParents(BuildContext context, {Random? random}) async {
  final passed = await showDialog<bool>(
    context: context,
    builder: (_) => ParentalGate(random: random ?? Random()),
  );
  if ((passed ?? false) && context.mounted) {
    await showDialog<void>(context: context, builder: (_) => const ParentsPanel());
  }
}

class ParentalGate extends StatefulWidget {
  const ParentalGate({super.key, required this.random});
  final Random random;

  @override
  State<ParentalGate> createState() => _ParentalGateState();
}

class _ParentalGateState extends State<ParentalGate> {
  late final int a = 3 + widget.random.nextInt(7);
  late final int b = 3 + widget.random.nextInt(7);
  late final List<int> options = () {
    final answer = a * b;
    final set = <int>{answer, answer + a, answer - b};
    while (set.length < 3) {
      set.add(answer + 1 + widget.random.nextInt(9));
    }
    return set.toList()..shuffle(widget.random);
  }();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ask a grown-up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('To continue, answer this question:'),
          const SizedBox(height: 12),
          Text(
            'What is $a × $b?',
            key: const Key('gate-question'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        for (final v in options)
          FilledButton(
            key: Key('gate-answer-$v'),
            onPressed: () => Navigator.pop(context, v == a * b),
            child: Text('$v', style: const TextStyle(fontSize: 20)),
          ),
      ],
    );
  }
}

class ParentsPanel extends StatelessWidget {
  const ParentsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return AlertDialog(
      title: const Text('For parents'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            SizedBox(height: 4),
            Text(privacySummary, key: Key('privacy-summary')),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('reset-progress'),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Reset all stars?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(
                    key: const Key('reset-confirm'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            );
            if (ok ?? false) progress.reset();
          },
          child: const Text('Reset progress'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
