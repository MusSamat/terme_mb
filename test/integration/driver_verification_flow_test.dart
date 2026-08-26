import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// Seed easy_localization's static instance directly so tr() resolves without a
// full EasyLocalization widget (which, in tests, doesn't render its child).
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tappjet_mb/providers/core_providers.dart';
import 'package:tappjet_mb/screens/profile/driver_verification_screen.dart';
import 'package:tappjet_mb/widgets/app_button.dart';

/// Integration: the driver-verification wizard must NOT advance past step 1
/// until the car data is valid — the whole point of «verify before next page».
void main() {
  late Box<dynamic> box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final raw = File('assets/l10n/ru.json').readAsStringSync();
    Localization.load(const Locale('ru'), translations: Translations(json.decode(raw) as Map<String, dynamic>));
    final dir = Directory.systemTemp.createTempSync('tj_verif');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('tappjet_verif');
  });

  Widget wrap(Widget child) => ProviderScope(
        overrides: [hiveBoxProvider.overrideWithValue(box)],
        child: MaterialApp(home: child),
      );

  testWidgets('step 1 gates «Далее» until the car form is valid', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400)); // tall enough to build all fields
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(const DriverVerificationScreen()));
    await tester.pumpAndSettle();

    // Step 1: make / model / plate are text fields; year + colour are selectors.
    expect(find.byType(TextField), findsNWidgets(3));

    // Tapping «Далее» with an empty form must NOT advance (still on step 1).
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.byType(AspectRatio), findsNothing, reason: 'empty form should not advance');

    // Colour has no catalog in tests → tapping the selector reveals a manual
    // field (which sits above the plate, so it becomes TextField index 2).
    await tester.tap(find.text('driver_reg.color_placeholder'.tr()));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4)); // make, model, colour, plate

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Toyota'); // make
    await tester.enterText(fields.at(1), 'Camry'); // model
    await tester.enterText(fields.at(2), 'белый'); // colour (manual, above plate)
    await tester.enterText(fields.at(3), '01KG123'); // plate
    await tester.pumpAndSettle();

    // Everything valid EXCEPT the year → still blocked.
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.byType(AspectRatio), findsNothing, reason: 'missing year should not advance');

    // Year: open the selector sheet, scroll to 2015 and pick it.
    await tester.tap(find.text('driver_reg.year_placeholder'.tr()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('2015'), 150, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2015'));
    await tester.pumpAndSettle();

    // Now valid → advances to step 2 (document capture); car fields are gone.
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.byType(AspectRatio), findsWidgets, reason: 'should show the doc capture on step 2');
    expect(find.byType(TextField), findsNothing, reason: 'car fields belong to step 1');
  });

  testWidgets('plate field normalizes input as the user types', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(const DriverVerificationScreen()));
    await tester.pumpAndSettle();
    final plate = find.byType(TextField).at(2);
    await tester.enterText(plate, '01 kg-123');
    await tester.pumpAndSettle();
    expect(find.text('01KG123'), findsOneWidget, reason: 'plate should be uppercased + stripped');
  });
}
