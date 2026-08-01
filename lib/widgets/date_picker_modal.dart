import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Calendar month-grid picker — 1:1 port of tappjet_ft DatePickerModal.
/// Per-day availability counts, weekend coral, today ring, selected brand.
/// Returns the chosen 'YYYY-MM-DD' (or '' when cleared) via [onChange].
Future<void> showDatePickerModal(
  BuildContext context, {
  required String value, // 'YYYY-MM-DD' or ''
  required ValueChanged<String> onChange,
  String? min,
  Map<String, int>? dayCounts,
}) {
  return showDialog<void>(
    useRootNavigator: true,
    context: context,
    builder: (ctx) => _CalendarDialog(value: value, onChange: onChange, min: min, dayCounts: dayCounts),
  );
}

const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _months = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog({required this.value, required this.onChange, this.min, this.dayCounts});
  final String value;
  final ValueChanged<String> onChange;
  final String? min;
  final Map<String, int>? dayCounts;

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late int _year;
  late int _month; // 0-based

  @override
  void initState() {
    super.initState();
    final base = _parse(widget.value) ?? DateTime.now();
    _year = base.year;
    _month = base.month - 1;
  }

  DateTime? _parse(String s) {
    if (s.isEmpty) return null;
    final p = s.split('-');
    if (p.length != 3) return null;
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  List<int?> _grid() {
    final first = DateTime(_year, _month + 1, 1);
    final offset = first.weekday - 1; // Mon=0
    final days = DateTime(_year, _month + 2, 0).day;
    return [
      ...List<int?>.filled(offset, null),
      for (var d = 1; d <= days; d++) d,
      ...List<int?>.filled((7 - (offset + days) % 7) % 7, null),
    ];
  }

  void _prevMonth() => setState(() {
        if (_month == 0) {
          _month = 11;
          _year--;
        } else {
          _month--;
        }
      });

  void _nextMonth() => setState(() {
        if (_month == 11) {
          _month = 0;
          _year++;
        } else {
          _month++;
        }
      });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final todayStr = ymd(DateTime.now());
    final grid = _grid();

    return Dialog(
      backgroundColor: dark ? InkColors.c900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('date_picker.select_date'.tr(),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: dark ? Colors.white : InkColors.c900)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navBtn(dark, Icons.chevron_left, _prevMonth),
                Text('${_months[_month]} $_year',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : InkColors.c900)),
                _navBtn(dark, Icons.chevron_right, _nextMonth),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var wi = 0; wi < _weekdays.length; wi++)
                  Expanded(
                    child: Center(
                      child: Text(_weekdays[wi],
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: wi >= 5 ? CoralColors.c400 : InkColors.c400)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.85,
              children: [
                for (final day in grid)
                  if (day == null)
                    const SizedBox()
                  else
                    _dayCell(dark, day, todayStr),
              ],
            ),
            if (widget.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  widget.onChange('');
                  Navigator.of(context).pop();
                },
                child: Text('date_picker.clear'.tr(),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: InkColors.c400)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _navBtn(bool dark, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? InkColors.c800 : InkColors.c100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 26, color: dark ? InkColors.c200 : InkColors.c700),
      ),
    );
  }

  Widget _dayCell(bool dark, int day, String todayStr) {
    final cellStr = ymd(DateTime(_year, _month + 1, day));
    final weekday = DateTime(_year, _month + 1, day).weekday; // 6,7 weekend
    final weekend = weekday >= 6;
    final selected = cellStr == widget.value;
    final isToday = cellStr == todayStr;
    final disabled = widget.min != null && cellStr.compareTo(widget.min!) < 0;
    final count = widget.dayCounts?[cellStr];

    Color textColor;
    if (selected) {
      textColor = Colors.white;
    } else if (disabled) {
      textColor = dark ? InkColors.c700 : InkColors.c300;
    } else if (isToday) {
      textColor = dark ? BrandColors.c300 : BrandColors.c600;
    } else if (weekend) {
      textColor = CoralColors.c500;
    } else {
      textColor = dark ? InkColors.c100 : InkColors.c800;
    }

    return GestureDetector(
      onTap: disabled
          ? null
          : () {
              widget.onChange(cellStr);
              Navigator.of(context).pop();
            },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? BrandColors.c600 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !selected ? Border.all(color: BrandColors.c500) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected || isToday ? FontWeight.w800 : FontWeight.w600,
                    color: textColor)),
            if (widget.dayCounts != null)
              Text(disabled ? '' : '${count ?? 0}',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.9)
                          : (count != null && count > 0
                              ? (dark ? BrandColors.c300 : BrandColors.c600)
                              : (dark ? InkColors.c600 : InkColors.c300)))),
          ],
        ),
      ),
    );
  }
}
