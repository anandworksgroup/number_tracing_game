import 'package:flutter/material.dart';

import '../app.dart';
import '../ui.dart';
import 'trace_screen.dart';

const maxNumber = 20;

class PickerScreen extends StatelessWidget {
  const PickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return Scaffold(
      body: Backdrop(
        child: Column(
          children: [
            const TopBar(title: Text('Pick a number')),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: maxNumber + 1,
                itemBuilder: (context, n) {
                  final stars = progress.stars[n] ?? 0;
                  return Pressable(
                    key: Key('tile-$n'),
                    semanticLabel: 'Number $n, $stars stars',
                    onTap: () => Navigator.of(context).push(route(TraceScreen(start: n))),
                    child: Container(
                      decoration: BoxDecoration(
                        color: stars > 0 ? const Color(0xFFFFFBE6) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: cardShadow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            child: Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 46,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: crayons[n % crayons.length],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 1; i <= 3; i++)
                                Icon(
                                  i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 18,
                                  color: gold,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
