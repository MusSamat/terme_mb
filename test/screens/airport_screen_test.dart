import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// Not re-exported: seed the static instance with the real ru strings.
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terme_mb/models/passenger_request.dart';
import 'package:terme_mb/models/place.dart';
import 'package:terme_mb/providers/core_providers.dart';
import 'package:terme_mb/providers/data_providers.dart';
import 'package:terme_mb/screens/airport/airport_screen.dart';
import 'package:terme_mb/widgets/airport_extras.dart';
import 'package:terme_mb/widgets/app_button.dart';
import 'package:terme_mb/widgets/map/plane_glyph.dart';

import '../models/airport_test.dart' show manas, osh;

class FileLoader extends AssetLoader {
  const FileLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) => SynchronousFuture(
      json.decode(File('$path/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>);
}

void main() {
  late Box<dynamic> box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(Directory.systemTemp.createTempSync('airport_test').path);
    box = await Hive.openBox<dynamic>('airport_test');
  });

  Future<void> pump(WidgetTester tester, Widget home, {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('kg')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('ru'),
      saveLocale: false,
      assetLoader: const FileLoader(),
      child: ProviderScope(
        overrides: [
          hiveBoxProvider.overrideWithValue(box),
          airportsProvider.overrideWith((ref) async => [manas, osh]),
          ...overrides,
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: home,
          ),
        ),
      ),
    ));
    Localization.load(const Locale('ru'),
        translations:
            Translations(json.decode(File('assets/l10n/ru.json').readAsStringSync()) as Map<String, dynamic>));
    await tester.pumpAndSettle();
  }

  AppButton findBtn(WidgetTester t) => t.widget<AppButton>(find.byKey(const ValueKey('airport-find')));

  testWidgets('step 1: two airport cards; choosing Ош prefills the served city + chips', (tester) async {
    await pump(tester, const AirportScreen());
    expect(find.byType(AirportCard), findsNWidgets(2));
    expect(find.text('Манас · Бишкек'), findsOneWidget);
    expect(find.text('В аэропорт'), findsNothing, reason: 'direction comes after the airport');

    await tester.tap(find.byKey(const ValueKey('airport-901')));
    await tester.pumpAndSettle();
    expect(find.text('В аэропорт'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('airport-other')), matching: find.text('Ош')), findsOneWidget);
    // Жалал-Абад oblast's «Манас» reads apart from the airport.
    expect(find.text('Жалал-Абадская область'), findsOneWidget);
    expect(findBtn(tester).onPressed, isNull, reason: 'no flight time yet');
  });

  testWidgets('flight time → suggested pickup, «Найти трансфер» enabled', (tester) async {
    final pickup = DateTime(2026, 10, 20, 6, 30);
    await pump(tester, const AirportScreen(), overrides: [
      pickupSuggestionProvider.overrideWith((ref, k) async => PickupSuggestion(
          pickupAt: pickup, travelMin: 30, bufferMin: 150, distanceKm: 24.6, flightType: k.flightType)),
    ]);
    await tester.tap(find.byKey(const ValueKey('airport-900')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Время вылета'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byType(TextButton)).last);
    await tester.pumpAndSettle();
    expect(find.text('Выезд в 06:30 — успеете к регистрации'), findsOneWidget);
    expect(find.text('25 км · ~30 мин в пути'), findsOneWidget);
    expect(findBtn(tester).onPressed, isNotNull);

    // «Из аэропорта»: landing time instead of a pickup.
    await tester.tap(find.text('Из аэропорта'));
    await tester.pumpAndSettle();
    expect(find.text('Прилёт 09:00'), findsOneWidget);
    expect(find.textContaining('Выезд в'), findsNothing);
  });

  testWidgets('request extras: icon + text, nothing for intercity', (tester) async {
    PassengerRequestItem req(String kind) => PassengerRequestItem.fromJson(
        {'id': 'r', 'kind': kind, 'originCity': 'A', 'destinationCity': 'B', 'meetWithSign': true, 'luggageCount': 2});
    await pump(
        tester,
        Scaffold(
          body: Column(children: [
            AirportExtras(request: req('airport')),
            AirportExtras(key: const ValueKey('intercity'), request: req('intercity')),
          ]),
        ));
    expect(find.text('С табличкой'), findsOneWidget);
    expect(find.text('Багаж: 2'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('intercity')), matching: find.byType(Icon)), findsNothing);
  });

  test('plane glyph fills the 24 box', () {
    final b = planeGlyphPath.getBounds();
    expect(b.left, closeTo(2, 0.01));
    expect(b.right, closeTo(21, 0.01));
    expect(b.top, closeTo(2, 0.01));
    expect(b.bottom, closeTo(21, 0.01));
  });
}
