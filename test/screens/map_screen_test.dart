import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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
import 'package:terme_mb/api/services/misc_services.dart';
import 'package:terme_mb/providers/core_providers.dart';
import 'package:terme_mb/providers/data_providers.dart';
import 'package:terme_mb/screens/map/map_overlays.dart';
import 'package:terme_mb/models/place.dart';
import 'package:terme_mb/screens/map/map_screen.dart';
import 'package:terme_mb/screens/map/route_results_map.dart';
import 'package:terme_mb/utils/location.dart';
import 'package:terme_mb/widgets/map/map_marker.dart';
import 'package:terme_mb/widgets/map/me_marker.dart';
import 'package:terme_mb/widgets/map/plane_glyph.dart';

/// Synchronous l10n loader — the rootBundle one does real async I/O that a
/// fake-async widget test never finishes after the first test in a file.
class FileLoader extends AssetLoader {
  const FileLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) => SynchronousFuture(
      json.decode(File('$path/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>);
}

class FakeLocation extends LocationService {
  FakeLocation(this.perm, {this.fix, this.afterRequest});
  LocPermission perm;
  final LatLngPoint? fix;
  final LocPermission? afterRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<LocPermission> status() async => perm;
  @override
  Future<LocPermission> request() async {
    requests++;
    return perm = afterRequest ?? perm;
  }

  @override
  Future<LatLngPoint?> lastKnown() async => perm == LocPermission.granted ? fix : null;
  @override
  Future<LatLngPoint?> refine() async => perm == LocPermission.granted ? fix : null;
  @override
  Future<bool> openSettings(LocPermission s) async {
    settingsOpened++;
    return true;
  }
}

class FakeCities extends CitiesService {
  FakeCities() : super(Dio());
  int calls = 0;

  @override
  Future<Place?> nearest(double lat, double lng) async {
    calls++;
    return const Place(id: 1, type: 'city', nameRu: 'Бишкек', nameKg: 'Бишкек', lat: 42.87, lng: 74.59);
  }
}

MapItem pin(String id, double km, {bool exact = true}) => MapItem(
      id: id,
      lat: 42.8746 + km / 111.2,
      lng: 74.5698,
      exact: exact,
      originCity: 'Бишкек',
      destinationCity: 'Ош',
      departureAt: DateTime.now().add(const Duration(days: 1)),
      seats: 3,
      price: 1200,
    );

void main() {
  late Box<dynamic> box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(Directory.systemTemp.createTempSync('map_test').path);
    box = await Hive.openBox<dynamic>('map_test');
  });

  void loadRu() => Localization.load(const Locale('ru'),
      translations: Translations(json.decode(File('assets/l10n/ru.json').readAsStringSync()) as Map<String, dynamic>));

  Future<void> pump(WidgetTester tester, FakeLocation loc, Widget home,
      {FakeCities? cities, double textScale = 1}) async {
    tester.view.physicalSize = const Size(360, 740);
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
          locationServiceProvider.overrideWithValue(loc),
          citiesServiceProvider.overrideWithValue(cities ?? FakeCities()),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
              child: child!,
            ),
            home: home,
          ),
        ),
      ),
    ));
    loadRu(); // the asset delegate doesn't finish under fake async
    await tester.pump();
    // disableAnimations → MeMarker's pulse is static, so the tree can settle.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  group('route form', () {
    testWidgets('not granted → pre-permission card, no OS prompt until «Разрешить»', (tester) async {
      final loc = FakeLocation(LocPermission.denied);
      await pump(tester, loc, const MapScreen(requests: false));
      expect(find.byType(PermissionCard), findsOneWidget);
      expect(find.text('Покажем поездки рядом с вами'), findsOneWidget);
      expect(loc.requests, 0);

      await tester.tap(find.text('Не сейчас'));
      await tester.pumpAndSettle();
      expect(find.byType(PermissionCard), findsNothing);
      expect(find.textContaining('Выберите откуда и куда'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Разрешить» prompts once, then fills «Откуда» with the nearest settlement', (tester) async {
      final loc =
          FakeLocation(LocPermission.denied, afterRequest: LocPermission.granted, fix: (lat: 42.8746, lng: 74.5698));
      final cities = FakeCities();
      await pump(tester, loc, const MapScreen(requests: false), cities: cities);
      await tester.tap(find.text('Разрешить'));
      await tester.pumpAndSettle();
      expect(loc.requests, 1);
      expect(cities.calls, 1);
      expect(find.text('Бишкек'), findsOneWidget);
      expect(find.text('Рядом с вами'), findsOneWidget);
    });

    testWidgets('permanently denied → «Открыть настройки»', (tester) async {
      final loc = FakeLocation(LocPermission.deniedForever);
      await pump(tester, loc, const MapScreen(requests: false));
      expect(find.text('Открыть настройки'), findsOneWidget);
      await tester.tap(find.text('Открыть настройки'));
      await tester.pumpAndSettle();
      expect(loc.settingsOpened, 1);
      expect(loc.requests, 0);
    });
  });

  testWidgets('results map: pins + me + «Рядом» sorted by distance; 360dp, 2× text', (tester) async {
    // OSM tiles can't load in tests — ignore only those image errors.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library != 'image resource service') onError?.call(d);
    };
    final loc = FakeLocation(LocPermission.granted, fix: (lat: 42.8746, lng: 74.5698));
    final opened = <String>[];
    await pump(
      tester,
      loc,
      Scaffold(
        body: RouteResultsMap(
          items: [pin('far', 6), pin('near', 1)],
          requests: false,
          origin: null,
          onOpen: opened.add,
        ),
      ),
      textScale: 2,
    );
    expect(find.byType(MapMarker), findsNWidgets(2));
    expect(find.byType(MeMarker), findsOneWidget);
    final tiles = tester.widgetList<NearbyTile>(find.byType(NearbyTile)).map((t) => t.item.id).toList();
    expect(tiles.first, 'near');

    await tester.tap(find.byKey(const ValueKey('near-near')));
    await tester.pumpAndSettle();
    expect(tester.widget<NearbyTile>(find.byKey(const ValueKey('near-near'))).selected, isTrue);
    expect(tester.widgetList<MapMarker>(find.byType(MapMarker)).where((m) => m.selected), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('near-near')));
    await tester.pumpAndSettle();
    expect(opened, ['near']);
    FlutterError.onError = onError;
    expect(tester.takeException(), isNull);
  });

  testWidgets('results map: nearby + truncated notes, settlement pins dimmed with a row hint', (tester) async {
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library != 'image resource service') onError?.call(d);
    };
    await pump(
      tester,
      FakeLocation(LocPermission.denied),
      Scaffold(
        body: RouteResultsMap(
          items: [pin('village', 3, exact: false), pin('pinned', 1)], // village departs first → top row
          requests: false,
          origin: null,
          nearby: true,
          truncated: true,
          onOpen: (_) {},
        ),
      ),
    );
    expect(find.text('Показаны ближайшие сёла'), findsOneWidget);
    expect(find.text('Показаны первые 500 по времени отправления'), findsOneWidget);
    expect(find.text('примерно, центр села'), findsOneWidget);
    final dimmed = tester.widgetList<Opacity>(
        find.ancestor(of: find.byType(MapMarker), matching: find.byType(Opacity)));
    expect(dimmed.map((o) => o.opacity).toList()..sort(), [0.75, 1.0]);

    await tester.tap(find.byKey(const ValueKey('near-village')));
    await tester.pumpAndSettle();
    final sel = tester.widgetList<Opacity>(
        find.ancestor(of: find.byType(MapMarker), matching: find.byType(Opacity)));
    expect(sel.every((o) => o.opacity == 1), isTrue, reason: 'the selected pin is never dimmed');
    FlutterError.onError = onError;
    expect(tester.takeException(), isNull);
  });

  testWidgets('results map without notes when the route matched exactly', (tester) async {
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library != 'image resource service') onError?.call(d);
    };
    await pump(
      tester,
      FakeLocation(LocPermission.denied),
      Scaffold(
        body: RouteResultsMap(items: [pin('a', 1)], requests: true, origin: null, onOpen: (_) {}),
      ),
    );
    expect(find.text('Показаны ближайшие сёла'), findsNothing);
    expect(find.text('Показаны первые 500 по времени отправления'), findsNothing);
    expect(find.text('примерно, центр села'), findsNothing);
    FlutterError.onError = onError;
    expect(tester.takeException(), isNull);
  });

  testWidgets('results map: the airport end gets the plane pin', (tester) async {
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library != 'image resource service') onError?.call(d);
    };
    await pump(
      tester,
      FakeLocation(LocPermission.denied),
      Scaffold(
        body: RouteResultsMap(
          items: [pin('a', 1)],
          requests: false,
          origin: null,
          airport: const Place(id: 900, type: 'airport', nameRu: 'Манас', nameKg: 'Манас', lat: 43.06, lng: 74.48),
          onOpen: (_) {},
        ),
      ),
    );
    expect(find.byType(AirportMarker), findsOneWidget);
    expect(find.byType(MapMarker), findsOneWidget);
    FlutterError.onError = onError;
    expect(tester.takeException(), isNull);
  });
}
