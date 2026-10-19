import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place.dart';
import '../providers/data_providers.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../utils/locale.dart';
import '../utils/location.dart';
import '../api/friendly_error.dart';
import 'app_toast.dart';

/// Place selection sheet — searches the SOATE directory (GET /cities) with a
/// short debounce. [nearMe] adds «Рядом со мной» (GPS → nearest settlement).
Future<Place?> showCityPicker(BuildContext context, {bool nearMe = false}) {
  return showModalBottomSheet<Place>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CityPickerSheet(nearMe: nearMe),
  );
}

/// Icon per place type — cities, villages and airports read apart at a glance.
IconData placeIcon(String type) => switch (type) {
      'airport' => Icons.flight_rounded,
      'capital' || 'city' => Icons.location_city_rounded,
      'town' => Icons.apartment_rounded,
      _ => Icons.place_outlined,
    };

/// Two-line place row (Yandex-style): name, then «район, область» in grey.
class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.place, required this.onTap, this.dense = false});

  final Place place;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kg = isKg(context);
    final sub = place.subtitle(kg);
    return ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : null,
      leading: Icon(placeIcon(place.type),
          size: dense ? 20 : 22, color: place.isAirport ? BrandColors.c600 : InkColors.c400),
      title: Text(place.name(kg),
          style: TextStyle(
              fontSize: dense ? 14 : 15,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : InkColors.c900)),
      subtitle: sub.isEmpty
          ? null
          : Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
      onTap: onTap,
    );
  }
}

/// «Рядом со мной» row: resolves the device position to its settlement.
class NearMeTile extends ConsumerStatefulWidget {
  const NearMeTile({super.key, required this.onPlace, this.dense = false});

  final ValueChanged<Place> onPlace;
  final bool dense;

  @override
  ConsumerState<NearMeTile> createState() => _NearMeTileState();
}

class _NearMeTileState extends ConsumerState<NearMeTile> {
  bool _busy = false;

  Future<void> _resolve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final p = await ref.read(locationServiceProvider).current();
      if (p == null || !inKyrgyzstan(p)) {
        _toast('location.unavailable'.tr());
        return;
      }
      final place = await ref.read(citiesServiceProvider).nearest(p.lat, p.lng);
      if (!mounted) return;
      if (place != null) {
        widget.onPlace(place);
      } else {
        _toast('location.unavailable'.tr());
      }
    } catch (_) {
      _toast('location.unavailable'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) => Toasts.error(msg);

  @override
  Widget build(BuildContext context) => ListTile(
        dense: widget.dense,
        visualDensity: widget.dense ? VisualDensity.compact : null,
        leading: _busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: BrandColors.c600))
            : const Icon(Icons.my_location_rounded, size: 21, color: BrandColors.c600),
        title: Text('location.near_me'.tr(),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: BrandColors.c600)),
        onTap: _resolve,
      );
}

/// Debounced place search shared by the pickers.
mixin PlaceSearch<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  List<Place> results = const [];
  bool searching = false;
  Object? searchError; // last search failed (offline…) — not «not found»
  Timer? _debounce;
  String _q = '';

  void searchPlaces(String v) {
    _q = v.trim();
    _debounce?.cancel();
    setState(() => searching = true);
    final q = _q;
    _debounce = Timer(Duration(milliseconds: q.isEmpty ? 0 : 280), () async {
      try {
        final r = await ref.read(citiesServiceProvider).search(q);
        if (mounted && _q == q) setState(() { results = r; searching = false; searchError = null; });
      } catch (e) {
        if (mounted && _q == q) setState(() { results = const []; searching = false; searchError = e; });
      }
    });
  }

  void retrySearch() => searchPlaces(_q);

  /// Empty-results body: a failed search shows the reason + retry.
  Widget emptyResults(double fontSize) => searchError != null
      ? Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(friendlyError(searchError!),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: InkColors.c400)),
            TextButton(onPressed: retrySearch, child: Text('errors.repeat'.tr())),
          ]),
        )
      : Center(
          child: Text('city_autocomplete.not_found'.tr(),
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: InkColors.c400)));

  void disposeSearch() => _debounce?.cancel();
}

class _CityPickerSheet extends ConsumerStatefulWidget {
  const _CityPickerSheet({required this.nearMe});
  final bool nearMe;

  @override
  ConsumerState<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<_CityPickerSheet> with PlaceSearch {
  @override
  void initState() {
    super.initState();
    searchPlaces('');
  }

  @override
  void dispose() {
    disposeSearch();
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
                onChanged: searchPlaces,
                style: TextStyle(fontSize: 15, color: dark ? Colors.white : InkColors.c900),
                decoration: InputDecoration(
                  hintText: 'city_autocomplete.enter_city'.tr(),
                  hintStyle: const TextStyle(color: InkColors.c400),
                  prefixIcon: const Icon(Icons.search, color: InkColors.c400),
                  suffixIcon: searching
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: InkColors.c400)))
                      : null,
                  filled: true,
                  fillColor: dark ? InkColors.c800 : InkColors.c100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (widget.nearMe) NearMeTile(onPlace: (p) => Navigator.of(context).pop(p)),
            Expanded(
              child: (!searching && results.isEmpty)
                  ? emptyResults(14)
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) =>
                          PlaceTile(place: results[i], onTap: () => Navigator.of(context).pop(results[i])),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
