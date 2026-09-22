import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/services/misc_services.dart' show CityHit;
import '../data/kg_cities.dart';
import '../providers/data_providers.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../utils/config.dart';

/// City selection sheet — searches the full /cities DB (autocomplete) with a
/// short debounce; falls back to the bundled short list offline / in mock mode.
Future<String?> showCityPicker(BuildContext context, {String? title}) {
  return showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CityPickerSheet(),
  );
}

class _CityPickerSheet extends ConsumerStatefulWidget {
  const _CityPickerSheet();

  @override
  ConsumerState<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<_CityPickerSheet> {
  String _query = '';
  late List<CityHit> _results = _localFilter('');
  bool _loading = false;
  Timer? _debounce;

  List<CityHit> _localFilter(String q) {
    final src = q.trim().isEmpty
        ? kgCities
        : kgCities.where((c) => c.toLowerCase().contains(q.toLowerCase()));
    return [for (final c in src) CityHit(name: c)];
  }

  void _onChanged(String v) {
    _query = v;
    final q = v.trim();
    _debounce?.cancel();

    if (q.isEmpty) {
      setState(() { _results = _localFilter(''); _loading = false; });
      return;
    }
    if (AppConfig.useMock) {
      setState(() { _results = _localFilter(q); _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final r = await ref.read(citiesServiceProvider).search(q);
        if (mounted && _query.trim() == q) setState(() { _results = r; _loading = false; });
      } catch (_) {
        if (mounted && _query.trim() == q) setState(() { _results = _localFilter(q); _loading = false; });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                onChanged: _onChanged,
                style: TextStyle(fontSize: 15, color: dark ? Colors.white : InkColors.c900),
                decoration: InputDecoration(
                  hintText: 'city_autocomplete.enter_city'.tr(),
                  hintStyle: const TextStyle(color: InkColors.c400),
                  prefixIcon: const Icon(Icons.search, color: InkColors.c400),
                  suffixIcon: _loading
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: InkColors.c400)))
                      : null,
                  filled: true,
                  fillColor: dark ? InkColors.c800 : InkColors.c100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: (!_loading && _results.isEmpty)
                  ? Center(child: Text('city_autocomplete.not_found'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final hit = _results[i];
                        final sub = hit.subtitle(context.locale.languageCode == 'kg');
                        return ListTile(
                          leading: const Icon(Icons.place_outlined, color: InkColors.c400),
                          title: Text(hit.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
                          subtitle: sub.isEmpty
                              ? null
                              : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
                          onTap: () => Navigator.of(context).pop(hit.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
