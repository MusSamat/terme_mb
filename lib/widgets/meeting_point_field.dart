import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/place.dart';
import '../screens/map/point_picker_screen.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../utils/locale.dart';

/// Optional exact meeting point inside the chosen place — the form works
/// without it; with it, the listing shows on the map where people board.
class MeetingPointField extends StatelessWidget {
  const MeetingPointField({
    super.key,
    required this.place,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.pickerTitle,
    this.accent = BrandColors.c600,
  });

  final Place? place;
  final MeetingPoint? value;
  final ValueChanged<MeetingPoint?> onChanged;
  final String label;
  final String pickerTitle;
  final Color accent;

  Future<void> _pick(BuildContext context) async {
    final p = place;
    if (p == null) return;
    final res = await pickMeetingPoint(context, place: p, initial: value, title: pickerTitle, accent: accent);
    if (res == null) return;
    onChanged(res.isRemoval ? null : res);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kg = isKg(context);
    final enabled = place != null;
    final set = value != null;
    final text = set
        ? (value!.label(kg).isEmpty ? 'point.on_map'.tr() : value!.label(kg))
        : (enabled ? 'point.add_hint'.tr() : 'point.choose_place_first'.tr());
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => _pick(context) : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl3),
            border: Border.all(color: set ? accent.withValues(alpha: 0.5) : (dark ? InkColors.c800 : InkColors.c100)),
            boxShadow: AppShadows.card,
          ),
          child: Row(children: [
            Icon(set ? Icons.location_on_rounded : Icons.add_location_alt_outlined, size: 20, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                const SizedBox(height: 2),
                Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: set ? accent : InkColors.c400)),
              ]),
            ),
            if (set)
              GestureDetector(
                onTap: () => onChanged(null),
                behavior: HitTestBehavior.opaque,
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 18, color: InkColors.c400)),
              )
            else
              const Icon(Icons.map_outlined, size: 18, color: InkColors.c400),
          ]),
        ),
      ),
    );
  }
}
