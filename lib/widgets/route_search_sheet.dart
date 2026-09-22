import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kg_cities.dart';
import '../providers/data_providers.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../utils/config.dart';

/// Route search sheet (Yandex «Межгород» style): Откуда + Куда shown together
/// at the top, one shared suggestions list below, keyboard under it. Max 95%
/// height. Returns the chosen (from, to) — or null if dismissed unchanged.
Future<({String from, String to})?> showRouteSearchSheet(
  BuildContext context, {
  required String from,
  required String to,
  required bool focusTo,
}) {
  return showModalBottomSheet<({String from, String to})>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RouteSearchSheet(from: from, to: to, focusTo: focusTo),
  );
}

class _RouteSearchSheet extends ConsumerStatefulWidget {
  const _RouteSearchSheet(
      {required this.from, required this.to, required this.focusTo});

  final String from;
  final String to;
  final bool focusTo;

  @override
  ConsumerState<_RouteSearchSheet> createState() => _RouteSearchSheetState();
}

class _RouteSearchSheetState extends ConsumerState<_RouteSearchSheet> {
  late final TextEditingController _fromCtrl =
      TextEditingController(text: widget.from);
  late final TextEditingController _toCtrl =
      TextEditingController(text: widget.to);
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();

  late bool _activeIsTo = widget.focusTo;
  List<String> _results = const [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fromFocus.addListener(() {
      if (_fromFocus.hasFocus && _activeIsTo) {
        setState(() => _activeIsTo = false);
        _search(_fromCtrl.text);
      }
    });
    _toFocus.addListener(() {
      if (_toFocus.hasFocus && !_activeIsTo) {
        setState(() => _activeIsTo = true);
        _search(_toCtrl.text);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      (_activeIsTo ? _toFocus : _fromFocus).requestFocus();
      _search(_activeIsTo ? _toCtrl.text : _fromCtrl.text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  List<String> _localFilter(String q) => q.trim().isEmpty
      ? kgCities
      : kgCities
          .where((c) => c.toLowerCase().contains(q.toLowerCase()))
          .toList();

  void _search(String v) {
    final q = v.trim();
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _results = kgCities;
        _loading = false;
      });
      return;
    }
    if (AppConfig.useMock) {
      setState(() {
        _results = _localFilter(q);
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final r = await ref.read(citiesServiceProvider).search(q);
        final active = _activeIsTo ? _toCtrl.text : _fromCtrl.text;
        if (mounted && active.trim() == q) {
          setState(() {
            _results = r;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _results = _localFilter(q);
            _loading = false;
          });
        }
      }
    });
  }

  void _pick(String city) {
    if (_activeIsTo) {
      _toCtrl.text = city;
      if (_fromCtrl.text.trim().isEmpty) {
        setState(() => _activeIsTo = false);
        _fromFocus.requestFocus();
        _search('');
      } else {
        _done();
      }
    } else {
      _fromCtrl.text = city;
      if (_toCtrl.text.trim().isEmpty) {
        setState(() => _activeIsTo = true);
        _toFocus.requestFocus();
        _search('');
      } else {
        _done();
      }
    }
  }

  void _done() => Navigator.of(context)
      .pop((from: _fromCtrl.text.trim(), to: _toCtrl.text.trim()));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final h = MediaQuery.of(context).size.height;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final bothSet =
        _fromCtrl.text.trim().isNotEmpty && _toCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * 0.95),
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
              Flexible(
                child: (!_loading && _results.isEmpty)
                    ? Center(
                        child: Text('city_autocomplete.not_found'.tr(),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: InkColors.c400)))
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 52,
                            color: dark ? InkColors.c900 : InkColors.c100),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: const Icon(Icons.place_outlined,
                              size: 20, color: InkColors.c400),
                          title: Text(_results[i],
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      dark ? Colors.white : InkColors.c900)),
                          onTap: () => _pick(_results[i]),
                        ),
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
        Icon(Icons.circle, size: 11, color: dot),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            onChanged: _search,
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
              setState(() {});
              _search('');
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
