import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../utils/locale.dart';
import 'city_picker.dart';

/// Route search sheet (Yandex «Межгород» style): Откуда + Куда shown together
/// at the top, one shared suggestions list below, keyboard under it. Max 95%
/// height. Returns the chosen (from, to) — or null if dismissed unchanged.
Future<({Place? from, Place? to})?> showRouteSearchSheet(
  BuildContext context, {
  required Place? from,
  required Place? to,
  required bool focusTo,
}) {
  return showModalBottomSheet<({Place? from, Place? to})>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RouteSearchSheet(from: from, to: to, focusTo: focusTo),
  );
}

class _RouteSearchSheet extends ConsumerStatefulWidget {
  const _RouteSearchSheet({required this.from, required this.to, required this.focusTo});

  final Place? from;
  final Place? to;
  final bool focusTo;

  @override
  ConsumerState<_RouteSearchSheet> createState() => _RouteSearchSheetState();
}

class _RouteSearchSheetState extends ConsumerState<_RouteSearchSheet> with PlaceSearch {
  late Place? _from = widget.from;
  late Place? _to = widget.to;
  late final TextEditingController _fromCtrl = TextEditingController();
  late final TextEditingController _toCtrl = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();

  late bool _activeIsTo = widget.focusTo;

  @override
  void initState() {
    super.initState();
    _fromFocus.addListener(() {
      if (_fromFocus.hasFocus && _activeIsTo) {
        setState(() => _activeIsTo = false);
        searchPlaces(_fromCtrl.text);
      }
    });
    _toFocus.addListener(() {
      if (_toFocus.hasFocus && !_activeIsTo) {
        setState(() => _activeIsTo = true);
        searchPlaces(_toCtrl.text);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kg = isKg(context);
      _fromCtrl.text = _from?.name(kg) ?? '';
      _toCtrl.text = _to?.name(kg) ?? '';
      (_activeIsTo ? _toFocus : _fromFocus).requestFocus();
      searchPlaces('');
    });
  }

  @override
  void dispose() {
    disposeSearch();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _onType(String v) {
    // Typing invalidates the picked place until a suggestion is chosen.
    setState(() => _activeIsTo ? _to = null : _from = null);
    searchPlaces(v);
  }

  void _pick(Place place) {
    final name = place.name(isKg(context));
    if (_activeIsTo) {
      _to = place;
      _toCtrl.text = name;
      if (_from == null) {
        setState(() => _activeIsTo = false);
        _fromFocus.requestFocus();
        searchPlaces('');
      } else {
        _done();
      }
    } else {
      _from = place;
      _fromCtrl.text = name;
      if (_to == null) {
        setState(() => _activeIsTo = true);
        _toFocus.requestFocus();
        searchPlaces('');
      } else {
        _done();
      }
    }
  }

  void _done() => Navigator.of(context).pop((from: _from, to: _to));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final h = MediaQuery.of(context).size.height;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final bothSet = _from != null && _to != null;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: ConstrainedBox(
        // Leave ~15% of the display at the top while typing (keyboard-aware).
        constraints: BoxConstraints(maxHeight: (h * 0.85 - kb).clamp(240.0, h * 0.85)),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? InkColors.c950 : InkColors.c50,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: dark ? InkColors.c700 : InkColors.c300,
                      borderRadius: BorderRadius.circular(999))),
              // Откуда / Куда together
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: dark ? InkColors.c900 : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.xl2),
                          border: Border.all(
                              color: dark ? InkColors.c800 : InkColors.c200),
                        ),
                        child: Column(children: [
                          _field(_fromCtrl, _fromFocus, BrandColors.c600,
                              'feed.from_placeholder'.tr(), dark, false),
                          Divider(
                              height: 1,
                              color: dark ? InkColors.c800 : InkColors.c100),
                          _field(_toCtrl, _toFocus, AccentColors.c500,
                              'feed.to_placeholder'.tr(), dark, true),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _closeBtn(dark, bothSet),
                  ],
                ),
              ),
              if (!_activeIsTo) NearMeTile(dense: true, onPlace: _pick),
              Flexible(
                child: (!searching && results.isEmpty)
                    ? emptyResults(13.5)
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 52,
                            color: dark ? InkColors.c900 : InkColors.c100),
                        itemBuilder: (_, i) =>
                            PlaceTile(place: results[i], dense: true, onTap: () => _pick(results[i])),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, FocusNode focus, Color dot,
          String hint, bool dark, bool isTo) =>
      Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: dot, borderRadius: BorderRadius.circular(9)),
          // Meaningful icons: origin dot for «Откуда», a flag for «Куда».
          child: Icon(isTo ? Icons.flag_rounded : Icons.trip_origin,
              size: 17, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            onChanged: _onType,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : InkColors.c900),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400),
            ),
          ),
        ),
        if (ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: () {
              ctrl.clear();
              _onType('');
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 16, color: InkColors.c400),
            ),
          ),
      ]);

  Widget _closeBtn(bool dark, bool bothSet) => GestureDetector(
        onTap: bothSet
            ? _done
            : () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: dark ? InkColors.c800 : InkColors.c100,
              shape: BoxShape.circle),
          child: Icon(bothSet ? Icons.check : Icons.close,
              size: 20, color: dark ? InkColors.c200 : InkColors.c700),
        ),
      );
}
