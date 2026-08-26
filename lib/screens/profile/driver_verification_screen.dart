import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../models/car.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/car_validation.dart';
import '../capture/camera_capture_screen.dart';
import '../../widgets/capture_overlay.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/car_pickers.dart';
import '../auth/auth_fields.dart';

/// Become-a-driver / verification — an Uber-style guided wizard:
///   Step 1 · car details (validated inline before «Далее»)
///   Steps 2–7 · one document photo per screen, each with its own visual guide
/// Submitted atomically to POST /drivers/verification.
class DriverVerificationScreen extends ConsumerStatefulWidget {
  const DriverVerificationScreen({super.key});

  @override
  ConsumerState<DriverVerificationScreen> createState() =>
      _DriverVerificationScreenState();
}

typedef _DocSlot = ({
  String cat,
  String labelKey,
  String descKey,
  IconData icon
});

class _DriverVerificationScreenState
    extends ConsumerState<DriverVerificationScreen> {
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  int _seats = 4;
  final Map<String, File> _docs = {};

  int _step = 0; // 0 = car details · 1..6 = one document each
  bool _triedNext = false; // reveal car-field errors after a «Далее» attempt
  bool _submitting = false;
  bool _colorManual = false; // colour typed by hand (off-catalog)

  static const List<_DocSlot> _docSlots = [
    (
      cat: 'license',
      labelKey: 'driver_reg.doc_license_label',
      descKey: 'driver_reg.doc_license_desc',
      icon: Icons.badge_outlined
    ),
    (
      cat: 'license_back',
      labelKey: 'driver_reg.doc_license_back_label',
      descKey: 'driver_reg.doc_license_back_desc',
      icon: Icons.flip_to_back
    ),
    (
      cat: 'car_passport',
      labelKey: 'driver_reg.doc_car_passport_label',
      descKey: 'driver_reg.doc_car_passport_desc',
      icon: Icons.description_outlined
    ),
    (
      cat: 'car_passport_back',
      labelKey: 'driver_reg.doc_car_passport_back_label',
      descKey: 'driver_reg.doc_car_passport_back_desc',
      icon: Icons.assignment_outlined
    ),
    (
      cat: 'car_photo',
      labelKey: 'driver_reg.doc_car_photo_label',
      descKey: 'driver_reg.doc_car_photo_desc',
      icon: Icons.directions_car_outlined
    ),
    (
      cat: 'selfie',
      labelKey: 'driver_reg.doc_selfie_label',
      descKey: 'driver_reg.doc_selfie_desc',
      icon: Icons.face_outlined
    ),
  ];

  int get _totalSteps => 1 + _docSlots.length;
  _DocSlot? get _currentDoc => _step == 0 ? null : _docSlots[_step - 1];
  bool get _isLastStep => _step == _docSlots.length;

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  // ── Per-field validation (mirrors the web err_car* rules) ────────────────────
  String? get _makeErr => CarValidation.makeValid(_make.text)
      ? null
      : 'driver_reg.err_carMake'.tr();
  String? get _modelErr => CarValidation.modelValid(_model.text)
      ? null
      : 'driver_reg.err_carModel'.tr();
  String? get _yearErr => CarValidation.yearValid(_year.text)
      ? null
      : 'driver_reg.err_carYear'.tr();
  String? get _colorErr => CarValidation.colorValid(_color.text)
      ? null
      : 'driver_reg.err_carColor'.tr();
  String? get _plateErr => CarValidation.plateValid(_plate.text)
      ? null
      : 'driver_reg.err_carPlate'.tr();

  bool get _carValid =>
      _makeErr == null &&
      _modelErr == null &&
      _yearErr == null &&
      _colorErr == null &&
      _plateErr == null;
  bool get _currentDocPicked =>
      _currentDoc != null && _docs.containsKey(_currentDoc!.cat);

  void _onPrimary() {
    if (_step == 0) {
      if (_carValid) {
        setState(() {
          _step = 1;
          _triedNext = false;
        });
      } else {
        setState(() => _triedNext = true); // reveal what's wrong
      }
      return;
    }
    if (!_currentDocPicked) return; // button is disabled anyway
    if (_isLastStep) {
      _submit();
    } else {
      setState(() => _step++);
    }
  }

  void _onBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.canPop() ? context.pop() : context.go('/profile');
    }
  }

  // Normalize the plate as the user types: uppercase, A–Z/0–9 only, max 10.
  void _onPlateChanged(String v) {
    final norm = CarValidation.normalizePlate(v);
    if (norm != v) {
      _plate.value = TextEditingValue(
          text: norm, selection: TextSelection.collapsed(offset: norm.length));
    }
    setState(() {});
  }

  CaptureGuide _cameraGuide(String cat) => switch (cat) {
        'selfie' => CaptureGuide.selfie,
        'car_photo' => CaptureGuide.car,
        'car_passport' || 'car_passport_back' => CaptureGuide.passport,
        _ => CaptureGuide.idCard, // license / license_back → ID card
      };

  // Per-document framing tip — shown on the capture placeholder and as the
  // live-camera hint (reuses the existing camera.*_hint strings).
  String _captureTip(String cat) => switch (cat) {
        'selfie' => 'camera.selfie_hint'.tr(),
        'car_photo' => 'camera.car_hint'.tr(),
        _ => 'camera.doc_hint'.tr(),
      };

  Future<void> _pick(String category) async {
    try {
      // In-app live camera WITH the guide overlay drawn over the feed (the OS
      // camera can't show our overlay). Falls back to image_picker internally.
      final img = await Navigator.of(context).push<File>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CameraCaptureScreen(
            guide: _cameraGuide(category),
            front: category == 'selfie',
            hint: _captureTip(category),
          ),
        ),
      );
      if (img != null && mounted) setState(() => _docs[category] = img);
    } catch (e) {
      Toasts.error(friendlyError(e));
    }
  }

  Future<void> _submit() async {
    if (!_carValid || _docs.length != _docSlots.length || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(driversServiceProvider).submit(
            carMake: _make.text.trim(),
            carModel: _model.text.trim(),
            carYear: int.parse(_year.text.trim()),
            carColor: _color.text.trim(),
            carPlate: _plate.text.trim().toUpperCase(),
            seatsCount: _seats,
            docs: _docs,
          );
      ref.invalidate(driverStatusProvider);
      if (!mounted) return;
      Toasts.success('driver_reg.success_title'.tr());
      context.canPop() ? context.pop() : context.go('/profile');
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final doc = _currentDoc;
    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading:
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        title: Text('driver_reg.title'.tr(),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _progressHeader(dark, doc),
                const SizedBox(height: 18),
                if (_step == 0) ..._carStep(dark) else _docCapture(dark, doc!),
              ],
            ),
          ),
          _bottomBar(dark),
        ],
      ),
    );
  }

  // ── Progress header — «Шаг X из 7» + a fractional bar + step title/subtitle ──
  Widget _progressHeader(bool dark, _DocSlot? doc) {
    final title =
        doc == null ? 'driver_reg.car_section'.tr() : doc.labelKey.tr();
    final subtitle =
        doc == null ? 'driver_reg.subtitle'.tr() : doc.descKey.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'driver_reg.step_progress'.tr(namedArgs: {
              'current': '${_step + 1}',
              'total': '$_totalSteps'
            }),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: GrapeColors.c600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            minHeight: 6,
            backgroundColor: dark ? InkColors.c800 : InkColors.c200,
            valueColor: const AlwaysStoppedAnimation(GrapeColors.c600),
          ),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: dark ? Colors.white : InkColors.c900)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: InkColors.c400)),
      ],
    );
  }

  void _fillFromCar(Car c) {
    setState(() {
      _make.text = c.make;
      _model.text = c.model;
      _year.text = c.year?.toString() ?? '';
      _plate.text = c.plate;
      _color.text = c.color ?? '';
      _colorManual = false;
      _seats = c.seatsCount;
      _triedNext = false;
    });
  }

  void _clearForm() {
    setState(() {
      _make.clear();
      _model.clear();
      _year.clear();
      _color.clear();
      _colorManual = false;
      _plate.clear();
      _seats = 4;
      _triedNext = false;
    });
  }

  // ── Step 1 · car details ─────────────────────────────────────────────────────
  List<Widget> _carStep(bool dark) {
    final showErr = _triedNext;
    final cars = ref.watch(carsProvider).valueOrNull ?? const <Car>[];
    return [
      // Pick an existing car from the garage (fills the form) — or just type a
      // new one below. Mirrors «add new OR select existing».
      if (cars.isNotEmpty) ...[
        Text('driver_reg.your_cars'.tr(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: InkColors.c400)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cars)
              GestureDetector(
                onTap: () => _fillFromCar(c),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _plate.text == c.plate
                        ? GrapeColors.c600
                        : (dark ? InkColors.c900 : Colors.white),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: _plate.text == c.plate
                            ? GrapeColors.c600
                            : (dark ? InkColors.c800 : InkColors.c200)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.directions_car,
                        size: 14,
                        color: _plate.text == c.plate
                            ? Colors.white
                            : GrapeColors.c600),
                    const SizedBox(width: 6),
                    Text('${c.make} ${c.model} · ${c.plate}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _plate.text == c.plate
                                ? Colors.white
                                : (dark ? InkColors.c200 : InkColors.c800))),
                  ]),
                ),
              ),
            // «+ Новое авто» — hidden once the driver has 3 cars (select only).
            if (cars.length < 3)
              GestureDetector(
                onTap: _clearForm,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: GrapeColors.c300),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add, size: 14, color: GrapeColors.c600),
                    const SizedBox(width: 4),
                    Text('profile.add_car'.tr(),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: GrapeColors.c600)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      _field(dark, 'driver_reg.make_label'.tr(), _make,
          'driver_reg.make_placeholder'.tr(),
          error: showErr ? _makeErr : null),
      _field(dark, 'driver_reg.model_label'.tr(), _model,
          'driver_reg.model_placeholder'.tr(),
          error: showErr ? _modelErr : null),
      _yearSelect(dark, showErr),
      _colorSelect(dark, showErr),
      _field(dark, 'driver_reg.plate_label'.tr(), _plate,
          'driver_reg.plate_placeholder'.tr(),
          caps: true,
          onChanged: _onPlateChanged,
          error: showErr ? _plateErr : null),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text('driver_reg.seats_label'.tr(),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
          const Spacer(),
          _seatBtn('−', _seats > 1, () => setState(() => _seats--)),
          SizedBox(
              width: 32,
              child: Text('$_seats',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : InkColors.c900))),
          _seatBtn('+', _seats < 7, () => setState(() => _seats++)),
        ]),
      ),
    ];
  }

  // ── Steps 2–7 · one guided document capture per screen ───────────────────────
  Widget _docCapture(bool dark, _DocSlot doc) {
    final file = _docs[doc.cat];
    final picked = file != null;
    return GestureDetector(
      onTap: () => _pick(doc.cat),
      behavior: HitTestBehavior.opaque,
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color:
                picked ? Colors.black : (dark ? InkColors.c900 : Colors.white),
            borderRadius: BorderRadius.circular(AppRadii.xl3),
            border: Border.all(
              color: picked
                  ? BrandColors.c500
                  : (dark ? InkColors.c700 : InkColors.c300),
              width: 2,
            ),
          ),
          child: picked
              ? Stack(fit: StackFit.expand, children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.refresh,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('driver_reg.retake'.tr(),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ]),
                    ),
                  ),
                  const Positioned(
                    left: 10,
                    bottom: 10,
                    child: Icon(Icons.check_circle,
                        size: 26, color: BrandColors.c400),
                  ),
                ])
              : Center(
                  // Clean placeholder with a framing tip — the real overlay guide
                  // is drawn over the live feed in CameraCaptureScreen, so we don't
                  // repeat the contour here.
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: GrapeColors.c600
                                .withValues(alpha: dark ? 0.18 : 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_camera_outlined,
                              size: 28, color: GrapeColors.c600),
                        ),
                        const SizedBox(height: 14),
                        Text(_captureTip(doc.cat),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: dark ? InkColors.c300 : InkColors.c500)),
                        const SizedBox(height: 8),
                        Text('driver_reg.capture_hint'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: GrapeColors.c600)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // Uber-style pinned CTA — the primary action is always in reach.
  Widget _bottomBar(bool dark) {
    final onDocStep = _step > 0;
    final canAdvance = _step == 0 ? true : _currentDocPicked;
    final label = _step == 0
        ? 'driver_reg.next'.tr()
        : _isLastStep
            ? (_submitting
                ? 'driver_reg.submitting'.tr()
                : 'driver_reg.submit_btn'.tr())
            : 'driver_reg.next'.tr();

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        border: Border(
            top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_step == 0 && _triedNext && !_carValid) ...[
          Text('driver_reg.fix_marked_fields'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CoralColors.c600)),
          const SizedBox(height: 10),
        ],
        if (onDocStep && !_currentDocPicked) ...[
          Text('driver_reg.capture_hint'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: InkColors.c400)),
          const SizedBox(height: 10),
        ],
        AppButton(
          label: label,
          variant: AppButtonVariant.grape,
          loading: _submitting,
          onPressed: (canAdvance && !_submitting) ? _onPrimary : null,
        ),
      ]),
    );
  }

  Widget _field(bool dark, String label, TextEditingController c, String hint,
      {bool number = false,
      bool caps = false,
      String? error,
      ValueChanged<String>? onChanged}) {
    final hasError = error != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: InkColors.c400)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: dark ? InkColors.c900 : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                  color: hasError
                      ? CoralColors.c500
                      : (dark ? InkColors.c800 : InkColors.c200),
                  width: hasError ? 2 : 1),
            ),
            child: TextField(
              controller: c,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              textCapitalization: caps
                  ? TextCapitalization.characters
                  : TextCapitalization.words,
              inputFormatters: number
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4)
                    ]
                  : null,
              onChanged: onChanged ?? (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : InkColors.c900),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: InkColors.c400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(error,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CoralColors.c600)),
          ],
        ],
      ),
    );
  }

  // Year — a plain year selector (2000..now), never free text.
  Widget _yearSelect(bool dark, bool showErr) {
    final err = showErr ? _yearErr : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('driver_reg.year_label'.tr().toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: InkColors.c400)),
        const SizedBox(height: 4),
        carSelectBox(
            dark: dark,
            value: _year.text,
            hint: 'driver_reg.year_placeholder'.tr(),
            onTap: _pickYearV),
        if (err != null) ...[
          const SizedBox(height: 4),
          Text(err,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CoralColors.c600)),
        ],
      ]),
    );
  }

  // Colour — a select like the brand picker (swatch + localized name), with a
  // free-text fallback for off-catalog colours.
  Widget _colorSelect(bool dark, bool showErr) {
    final err = showErr ? _colorErr : null;
    final colors =
        ref.watch(carColorsProvider).valueOrNull ?? const <CarColor>[];
    final isCustom = _color.text.trim().isNotEmpty &&
        colors.isNotEmpty &&
        !colors.any((c) => c.nameRu == _color.text);
    CarColor? sel;
    for (final c in colors) {
      if (c.nameRu == _color.text) {
        sel = c;
        break;
      }
    }
    final ky = carLocaleIsKy(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('driver_reg.color_label'.tr().toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: InkColors.c400)),
        const SizedBox(height: 4),
        if (_colorManual || isCustom) ...[
          TextFieldBox(
              controller: _color,
              dark: dark,
              hint: 'driver_reg.color_placeholder'.tr(),
              onChanged: () => setState(() {})),
          if (colors.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                _colorManual = false;
                _color.clear();
              }),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text('profile.from_list'.tr(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GrapeColors.c600)),
              ),
            ),
        ] else
          carSelectBox(
            dark: dark,
            value: sel != null ? (ky ? sel.nameKy : sel.nameRu) : '',
            hint: 'driver_reg.color_placeholder'.tr(),
            onTap: _pickColorV,
            leading: sel != null ? carSwatch(sel.hex, size: 18) : null,
          ),
        if (err != null) ...[
          const SizedBox(height: 4),
          Text(err,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CoralColors.c600)),
        ],
      ]),
    );
  }

  Future<void> _pickYearV() async {
    final picked = await showCarYearPicker(context,
        dark: Theme.of(context).brightness == Brightness.dark);
    if (picked == null || !mounted) return;
    setState(() => _year.text = picked.toString());
  }

  Future<void> _pickColorV() async {
    final colors =
        ref.read(carColorsProvider).valueOrNull ?? const <CarColor>[];
    if (colors.isEmpty) {
      setState(() => _colorManual = true);
      return;
    }
    final picked = await showCarColorPicker(context,
        dark: Theme.of(context).brightness == Brightness.dark, colors: colors);
    if (picked == null || !mounted) return;
    if (picked == kCarManual) {
      setState(() {
        _colorManual = true;
        _color.clear();
      });
      return;
    }
    setState(() {
      _color.text = picked;
      _colorManual = false;
    });
  }

  Widget _seatBtn(String label, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: enabled ? GrapeColors.c600 : InkColors.c300,
              borderRadius: BorderRadius.circular(10)),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ),
      );
}
