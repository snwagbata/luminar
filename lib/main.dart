import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import 'package:luminar/config/dependencies.dart';
import 'package:luminar/data/services/ble/reactive_ble_service.dart';
import 'package:luminar/data/services/home_store.dart';
import 'package:luminar/ui/core/theme.dart';
import 'package:luminar/ui/features/home/views/home_screen.dart';
import 'package:luminar/widget_entry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled in google_fonts/; never fetch at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final f in ['Figtree', 'BricolageGrotesque']) {
      yield LicenseEntryWithLineBreaks([f], await rootBundle.loadString('google_fonts/OFL-$f.txt'));
    }
  });
  unawaited(HomeWidget.registerInteractivityCallback(widgetTapped));
  final deps = Dependencies(ble: ReactiveBleService(), store: SecureHomeStore());
  runApp(MultiProvider(providers: deps.providers, child: const LuminarApp()));
}

class LuminarApp extends StatelessWidget {
  const LuminarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luminar',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(viewModel: context.read()),
    );
  }
}
