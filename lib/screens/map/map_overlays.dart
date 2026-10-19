import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../api/services/misc_services.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/api_format.dart';
import '../../utils/date_format.dart';
import '../../utils/locale.dart';
import '../../utils/location.dart';
import '../../widgets/app_button.dart';
import '../../widgets/map/car_glyph.dart';
import '../../widgets/map/passenger_glyph.dart';

Color _surface(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? InkColors.c900 : Colors.white;

Color _text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white : InkColors.c900;

/// Shows [PermissionCard] as a bottom sheet and returns the resulting status.
/// The OS prompt appears only from «Разрешить» (never on its own); a dismissed
/// prompt closes the card, «denied forever» turns it into «Открыть настройки».
Future<LocPermission> askLocationPermission(BuildContext context, LocationService loc, LocPermission status) async {
  var s = status;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => PermissionCard(
        status: s,
        onAllow: () async {
          s = await loc.request();
          if (!ctx.mounted) return;
          if (s == LocPermission.granted || s == LocPermission.denied) {
            Navigator.of(ctx).pop();
          } else {
            setSheet(() {});
          }
        },
        onSettings: () {
          loc.openSettings(s);
          Navigator.of(ctx).pop();
        },
        onLater: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
  return s;
}

/// Pre-permission card shown BEFORE the OS prompt (and instead of it when the
/// permission is permanently denied or location services are off).
class PermissionCard extends StatelessWidget {
  const PermissionCard({
    super.key,
    required this.status,
    required this.onAllow,
    required this.onSettings,
    required this.onLater,
  });

  final LocPermission status;
  final VoidCallback onAllow;
  final VoidCallback onSettings;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final settings = status == LocPermission.deniedForever || status == LocPermission.serviceOff;
    final body = switch (status) {
      LocPermission.deniedForever => 'map.perm_denied_body',
      LocPermission.serviceOff => 'map.perm_off_body',
      _ => 'map.perm_body',
    };
    return Material(
      color: _surface(context),
      elevation: 12,
      shadowColor: const Color(0x401C1917),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: BrandColors.c50, shape: BoxShape.circle),
              child: const Icon(Icons.near_me_rounded, color: BrandColors.c600, size: 26),
            ),
            const SizedBox(height: 14),
            Text('map.perm_title'.tr(),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _text(context))),
            const SizedBox(height: 6),
            Text(body.tr(),
                style: const TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: InkColors.c500)),
            const SizedBox(height: 18),
            AppButton(
              label: (settings ? 'map.open_settings' : 'map.perm_allow').tr(),
              onPressed: settings ? onSettings : onAllow,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onLater,
                style: TextButton.styleFrom(foregroundColor: InkColors.c600, minimumSize: const Size.fromHeight(48)),
                child: Text('map.perm_later'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Slim «turn on location» banner under the filters (no permission).
class LocationBanner extends StatelessWidget {
  const LocationBanner({super.key, required this.onEnable});
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) => Material(
        color: _surface(context),
        elevation: 3,
        shadowColor: const Color(0x331C1917),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(children: [
            const Icon(Icons.location_off_rounded, size: 18, color: InkColors.c500),
            const SizedBox(width: 8),
            Expanded(
              child: Text('map.banner'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text(context))),
            ),
            TextButton(
              onPressed: onEnable,
              style: TextButton.styleFrom(foregroundColor: BrandColors.c700),
              child: Text('map.banner_action'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      );
}

/// Fixed part of the «Рядом» sheet (handle + title + count) — also used to
/// size the peek.
class NearbyHeader extends StatelessWidget {
  const NearbyHeader({
    super.key,
    required this.requests,
    required this.count,
    this.nearby = false,
    this.truncated = false,
  });
  final bool requests;
  final int count;
  final bool nearby;
  final bool truncated;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Column(children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text('map.nearby'.tr(),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _text(context))),
            ),
            if (count > 0)
              Flexible(
                child: Text((requests ? 'map.nearby_requests' : 'map.nearby_trips').plural(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: InkColors.c500)),
              ),
          ]),
          if (nearby) _note(Icons.near_me_outlined, 'map.nearby_villages'.tr(), AccentColors.c700),
          if (truncated) _note(Icons.info_outline_rounded, 'map.truncated'.tr(), InkColors.c500),
        ]),
      );

  Widget _note(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      );
}

/// One row of the «Рядом» list: glyph, route, time · seats · price, distance.
class NearbyTile extends StatelessWidget {
  const NearbyTile({
    super.key,
    required this.item,
    required this.requests,
    required this.selected,
    required this.onTap,
    this.km,
    this.showOpen = false,
  });

  final MapItem item;
  final bool requests;
  final bool selected;
  final double? km;
  final bool showOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kg = isKg(context);
    final when = departureLabel(item.departureAt);
    final seats = (requests ? 'map.seats_needed' : 'map.seats_free').tr(namedArgs: {'n': '${item.seats}'});
    final meta = [
      '${when.date}, ${when.time}',
      seats,
      if (!requests && item.price != null) '${item.price} ${'map.som_per_seat'.tr()}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? BrandColors.c50 : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: selected ? BrandColors.c600 : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: selected ? InkColors.c900 : BrandColors.c600, shape: BoxShape.circle),
                child: requests
                    ? const PassengerGlyph(size: 20, color: Colors.white)
                    : const CarGlyph(size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${item.originName(kg)} → ${item.destinationName(kg)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected ? InkColors.c900 : _text(context))),
                  const SizedBox(height: 2),
                  Text(meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c500)),
                  if (!item.exact) ...[
                    const SizedBox(height: 2),
                    Text('map.approx_village'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
                  ],
                  if (showOpen) ...[
                    const SizedBox(height: 6),
                    Text((requests ? 'map.open_request' : 'map.open_trip').tr(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BrandColors.c700)),
                  ],
                ]),
              ),
              if (km != null) ...[
                const SizedBox(width: 8),
                Text(distanceLabel(km!),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BrandColors.c700)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
