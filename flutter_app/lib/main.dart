import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/audio.dart';
import 'src/progress.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Full screen so small fingers don't hit the system bars.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final progress = await Progress.load();
  Audio.instance.init();
  runApp(TraceApp(progress: progress));
}
