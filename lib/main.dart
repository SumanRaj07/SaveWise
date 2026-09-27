import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local/local_store.dart';
import 'data/repositories/finance_repository.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark theme is the default, so the system bars are told about it before the
  // first frame rather than flashing white on launch.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF07100D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final AppState state = AppState(FinanceRepository(LocalStore()));

  // Everything is read from the device before the first frame. It is a few
  // kilobytes of local JSON, so this costs milliseconds and buys a dashboard
  // that is correct the instant it appears.
  await state.bootstrap();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const SaveWiseApp(),
    ),
  );
}
