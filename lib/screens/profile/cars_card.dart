import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/friendly_error.dart';
import '../../models/car.dart';
import '../../providers/data_providers.dart';
import '../../utils/car_validation.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/car_pickers.dart';
import '../auth/auth_fields.dart';

/// Driver cars — list from /cars with add + delete. Replaces the hardcoded
/// single-car placeholder.
class CarsCard extends ConsumerWidget {
  const CarsCard({super.key, required this.dark});
  final bool dark;

  static const _maxCars = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carsAsync = ref.watch(carsProvider);
    final count = carsAsync.valueOrNull?.length ?? 0;
    final canAdd = count < _maxCars;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('profile.cars_section'.tr().toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400)),
        ),
        // Add is capped at 3 cars — at the limit, show the count instead.
        if (canAdd)
          GestureDetector(
            onTap: () => _showAdd(context, ref),
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              const Icon(Icons.add, size: 16, color: GrapeColors.c600),
              const SizedBox(width: 2),
              Text('profile.add_car'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GrapeColors.c600)),
            ]),
          )
        else
          Text('$count/$_maxCars', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: InkColors.c400)),
      ]),
      const SizedBox(height: 12),
      carsAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: GrapeColors.c500))),
        error: (e, _) => Text(friendlyError(e), style: const TextStyle(fontSize: 13, color: CoralColors.c600)),
        data: (cars) => cars.isEmpty
            ? Text('profile.no_cars'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400))
            : Column(children: [for (final c in cars) _row(context, ref, c)]),
      ),
    ]);
  }

  Widget _row(BuildContext context, WidgetRef ref, Car car) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: dark ? GrapeColors.c500.withValues(alpha: 0.15) : GrapeColors.c50, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.directions_car, color: GrapeColors.c600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(car.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
            Text('${car.plate} · ${car.color ?? ''} · ${'profile.seats_n'.tr(namedArgs: {'n': '${car.seatsCount}'})}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400)),
          ]),
        ),
        IconButton(
          onPressed: () async {
            final ok = await showConfirmModal(
              context,
              icon: Icons.delete_outline,
              title: 'profile.delete_car'.tr(),
              body: car.title,
              confirmLabel: 'profile.delete_car'.tr(),
              cancelLabel: 'book_form.cancel'.tr(),
              danger: true,
            );
            if (!ok) return;
            try {
              await ref.read(carsServiceProvider).remove(car.id);
              ref.invalidate(carsProvider);
            } catch (e) {
              if (context.mounted) Toasts.error(friendlyError(e));
            }
          },
          icon: const Icon(Icons.delete_outline, size: 20, color: CoralColors.c500),
        ),
      ]),
    );
  }

  void _showAdd(BuildContext context, WidgetRef ref) => showAddCarSheet(context, dark: dark);
}

/// Opens the add-car bottom sheet (reused by the create-trip screen). On save it
/// invalidates [carsProvider] so any watcher refreshes.
void showAddCarSheet(BuildContext context, {required bool dark}) {
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddCarSheet(dark: dark),
  );
}

class _AddCarSheet extends ConsumerStatefulWidget {
  const _AddCarSheet({required this.dark});
  final bool dark;
  @override
  ConsumerState<_AddCarSheet> createState() => _AddCarSheetState();
}

class _AddCarSheetState extends ConsumerState<_AddCarSheet> {
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  final _color = TextEditingController();
  final _year = TextEditingController();
  int _seats = 4;
  bool _loading = false;

  // Catalog picker state — free-text fallback when the brand/model isn't listed.
  int? _brandId;
  bool _brandManual = false;
  bool _modelManual = false;
  bool _colorManual = false;

  // Shared validation — same rules as the driver-verification wizard.
  bool get _valid =>
      CarValidation.makeValid(_make.text) && CarValidation.modelValid(_model.text) && CarValidation.plateValid(_plate.text);

  void _onPlateChanged() {
    final norm = CarValidation.normalizePlate(_plate.text);
    if (norm != _plate.text) {
      _plate.value = TextEditingValue(text: norm, selection: TextSelection.collapsed(offset: norm.length));
    }
    setState(() {});
  }

  static const _kManual = '__manual__';

  // Brand → model pickers with a free-text fallback (saved as text either way).
  Widget _brandField(bool dark) {
    if (_brandManual) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFieldBox(controller: _make, dark: dark, hint: 'profile.car_make'.tr(), onChanged: () => setState(() {})),
        _fromListBtn(() => setState(() {
              _brandManual = false;
              _make.clear();
              _brandId = null;
            })),
      ]);
    }
    return _selectBox(dark, _make.text, 'profile.car_make'.tr(), _pickBrand);
  }

  Widget _modelField(bool dark) {
    if (_brandManual || _modelManual) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFieldBox(controller: _model, dark: dark, hint: 'profile.car_model'.tr(), onChanged: () => setState(() {})),
        if (!_brandManual) _fromListBtn(() => setState(() { _modelManual = false; _model.clear(); })),
      ]);
    }
    return _selectBox(dark, _model.text, 'profile.car_model'.tr(), _brandId == null ? null : _pickModel);
  }

  Widget _fromListBtn(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text('profile.from_list'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GrapeColors.c600)),
        ),
      );

  // Colour — a select like the brand picker: swatch + localized name, with a
  // free-text fallback (value saved is the canonical Russian name).
  Widget _colorField(bool dark) {
    final colors = ref.watch(carColorsProvider).valueOrNull ?? const <CarColor>[];
    final isCustom = _color.text.trim().isNotEmpty && colors.isNotEmpty && !colors.any((c) => c.nameRu == _color.text);
    CarColor? sel;
    for (final c in colors) {
      if (c.nameRu == _color.text) { sel = c; break; }
    }
    final ky = carLocaleIsKy(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('profile.car_color'.tr().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c400)),
      const SizedBox(height: 6),
      if (_colorManual || isCustom) ...[
        TextFieldBox(controller: _color, dark: dark, hint: 'profile.car_color'.tr(), onChanged: () => setState(() {})),
        if (colors.isNotEmpty) _fromListBtn(() => setState(() { _colorManual = false; _color.clear(); })),
      ] else
        carSelectBox(
          dark: dark,
          value: sel != null ? (ky ? sel.nameKy : sel.nameRu) : '',
          hint: 'profile.car_color'.tr(),
          onTap: _pickColor,
          leading: sel != null ? carSwatch(sel.hex, size: 18) : null,
        ),
    ]);
  }

  Future<void> _pickColor() async {
    final colors = ref.read(carColorsProvider).valueOrNull ?? const <CarColor>[];
    if (colors.isEmpty) { setState(() => _colorManual = true); return; }
    final picked = await showCarColorPicker(context, dark: widget.dark, colors: colors);
    if (picked == null || !mounted) return;
    if (picked == kCarManual) { setState(() { _colorManual = true; _color.clear(); }); return; }
    setState(() { _color.text = picked; _colorManual = false; });
  }

  Future<void> _pickYear() async {
    final picked = await showCarYearPicker(context, dark: widget.dark);
    if (picked == null || !mounted) return;
    setState(() => _year.text = picked.toString());
  }

  Widget _selectBox(bool dark, String value, String hint, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: dark ? InkColors.c800 : InkColors.c50,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
        ),
        child: Row(children: [
          Expanded(
            child: Text(value.isEmpty ? hint : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: value.isEmpty ? InkColors.c400 : (dark ? Colors.white : InkColors.c900))),
          ),
          Icon(Icons.expand_more, size: 20, color: onTap == null ? InkColors.c300 : InkColors.c500),
        ]),
      ),
    );
  }

  Future<void> _pickBrand() async {
    try {
      final brands = await ref.read(carBrandsProvider.future);
      if (brands.isEmpty) {
        setState(() { _brandManual = true; _modelManual = true; });
        return;
      }
      final picked = await _showListPicker('profile.car_make'.tr(), brands.map((b) => b.name).toList());
      if (picked == null || !mounted) return;
      if (picked == _kManual) {
        setState(() { _brandManual = true; _modelManual = true; _make.clear(); _model.clear(); _brandId = null; });
        return;
      }
      final b = brands.firstWhere((x) => x.name == picked);
      setState(() { _make.text = b.name; _brandId = b.id; _model.clear(); _modelManual = false; });
    } catch (_) {
      setState(() { _brandManual = true; _modelManual = true; });
    }
  }

  Future<void> _pickModel() async {
    final id = _brandId;
    if (id == null) return;
    try {
      final models = await ref.read(carModelsProvider(id).future);
      final picked = await _showListPicker('profile.car_model'.tr(), models.map((m) => m.name).toList());
      if (picked == null || !mounted) return;
      if (picked == _kManual) {
        setState(() { _modelManual = true; _model.clear(); });
        return;
      }
      setState(() => _model.text = picked);
    } catch (_) {
      setState(() => _modelManual = true);
    }
  }

  Future<String?> _showListPicker(String title, List<String> options) {
    final dark = widget.dark;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final filtered = options.where((o) => o.toLowerCase().contains(query.toLowerCase())).toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4))),
            padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setSheet(() => query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'common.search'.tr(),
                    filled: true,
                    fillColor: dark ? InkColors.c800 : InkColors.c50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final o in filtered)
                      ListTile(
                        title: Text(o, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
                        onTap: () => Navigator.pop(ctx, o),
                      ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined, size: 20, color: GrapeColors.c600),
                      title: Text('profile.manual_entry'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: GrapeColors.c600)),
                      onTap: () => Navigator.pop(ctx, _kManual),
                    ),
                  ],
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _plate.dispose();
    _color.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(carsServiceProvider).create(
            make: _make.text.trim(),
            model: _model.text.trim(),
            plate: _plate.text.trim().toUpperCase(),
            color: _color.text.trim(),
            year: int.tryParse(_year.text.trim()),
            seatsCount: _seats,
          );
      ref.invalidate(carsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Toasts.error(friendlyError(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 14),
          Text('profile.add_car'.tr(), style: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _brandField(dark)),
            const SizedBox(width: 10),
            Expanded(child: _modelField(dark)),
          ]),
          const SizedBox(height: 10),
          TextFieldBox(controller: _plate, dark: dark, hint: 'profile.car_plate'.tr(), textCapitalization: TextCapitalization.characters, onChanged: _onPlateChanged),
          const SizedBox(height: 10),
          carSelectBox(dark: dark, value: _year.text, hint: 'driver_reg.year_placeholder'.tr(), onTap: _pickYear),
          const SizedBox(height: 10),
          _colorField(dark),
          const SizedBox(height: 12),
          Row(children: [
            Text('profile.seats_label'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
            const Spacer(),
            _seatBtn('−', _seats > 1, () => setState(() => _seats--)),
            SizedBox(width: 32, child: Text('$_seats', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900))),
            _seatBtn('+', _seats < 7, () => setState(() => _seats++)),
          ]),
          const SizedBox(height: 16),
          AppButton(label: 'profile.add_car'.tr(), variant: AppButtonVariant.grape, loading: _loading, onPressed: _valid ? _submit : null),
        ]),
      ),
    );
  }

  Widget _seatBtn(String label, bool enabled, VoidCallback onTap) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: enabled ? GrapeColors.c600 : InkColors.c300, borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      );
}
