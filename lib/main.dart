import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'providers/core_providers.dart';
import 'utils/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Release builds render a build-phase exception as a BLANK white box, which
  // reads as "the tab is empty/broken" with zero diagnostics. Surface a compact
  // error card instead so field screenshots tell us what actually threw.
  ErrorWidget.builder = (details) => Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Ошибка экрана: ${details.exceptionAsString()}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFFE11D48)),
            ),
          ),
        ),
      );

  await Hive.initFlutter();
  final box = await Hive.openBox<dynamic>(StorageKeys.box);

  final startLocale = box.get(StorageKeys.locale) as String?;

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('kg')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('ru'),
      startLocale: startLocale != null ? Locale(startLocale) : null,
      child: ProviderScope(
        overrides: [
          hiveBoxProvider.overrideWithValue(box),
        ],
        child: const TermeApp(),
      ),
    ),
  );
}
