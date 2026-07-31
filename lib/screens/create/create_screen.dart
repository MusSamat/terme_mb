import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/seats_stepper.dart';

/// Unified create screen — port of tappjet_ft create-screen. Drivers publish a
/// trip, passengers post a ride request; the intent toggle switches copy and
/// accent. Mock (no backend) — submit shows a success toast.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  late bool _asDriver;
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _price = TextEditingController();
  int _dateIndex = 0;
  int _seats = 1;
  final Set<String> _prefs = {};

  static const _dateKeys = [
    'feed.today',
    'create.date_tomorrow',
    'create.date_dayafter',
    'create.date_flexible',
  ];
  static const _prefKeys = [
    'create.pref_clean',
    'create.pref_music',
    'create.pref_no_smoking',
    'create.pref_ac',
    'create.pref_pets',
    'create.pref_quiet',
    'create.pref_chat',
    'create.pref_women_only',
  ];

  @override
  void initState() {
    super.initState();
    _asDriver = ref.read(authProvider).activeMode == ActiveMode.driver;
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _price.dispose();
    super.dispose();
  }

  Color get _accent => _asDriver ? GrapeColors.c600 : BrandColors.c600;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(_asDriver ? 'create.title_driver'.tr() : 'create.title_passenger'.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          _intentToggle(dark),
          const SizedBox(height: 16),
          _routeCard(dark),
          const SizedBox(height: 16),
          _sectionLabel('create.time_label'.tr(), dark),
          const SizedBox(height: 8),
          _dateChips(dark),
          const SizedBox(height: 16),
          _seatsRow(dark),
          const SizedBox(height: 16),
          _priceField(dark),
          const SizedBox(height: 16),
          _prefsSection(dark),
          const SizedBox(height: 20),
          Text('create.consent_phone'.tr(),
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
          const SizedBox(height: 12),
          AppButton(
            label: _asDriver ? 'create.submit_driver'.tr() : 'create.submit_passenger'.tr(),
            variant: _asDriver ? AppButtonVariant.grape : AppButtonVariant.brand,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('create.published_title'.tr())),
    );
    context.canPop() ? context.pop() : context.go('/');
  }

  Widget _intentToggle(bool dark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
      ),
      child: Row(
        children: [
          _intentTab('create.title_driver'.tr().replaceAll(' 🚗', ''), 'roles.driver'.tr(), _asDriver,
              GrapeColors.c600, () => setState(() => _asDriver = true), dark),
          _intentTab('create.title_passenger'.tr().replaceAll(' 🙌', ''), 'roles.passenger'.tr(), !_asDriver,
              BrandColors.c600, () => setState(() => _asDriver = false), dark),
        ],
      ),
    );
  }

  Widget _intentTab(String title, String sub, bool active, Color color, VoidCallback onTap, bool dark) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text(sub,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : (dark ? InkColors.c400 : InkColors.c500))),
        ),
      ),
    );
  }

  Widget _routeCard(bool dark) {
    return _card(
      dark,
      Stack(
        alignment: Alignment.centerRight,
        children: [
          Column(
            children: [
              _field(dark, Icons.trip_origin, _from, 'create.from_placeholder'.tr()),
              Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
              _field(dark, Icons.place, _to, 'create.to_placeholder'.tr()),
            ],
          ),
          GestureDetector(
            onTap: () {
              final t = _from.text;
              _from.text = _to.text;
              _to.text = t;
              setState(() {});
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: dark ? InkColors.c800 : InkColors.c100,
                shape: BoxShape.circle,
                border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
              ),
              child: Icon(Icons.swap_vert, size: 18, color: dark ? InkColors.c200 : InkColors.c600),
            ),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
    );
  }

  Widget _field(bool dark, IconData icon, TextEditingController c, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: dark ? InkColors.c400 : InkColors.c400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: c,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : InkColors.c900),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: InkColors.c400, fontWeight: FontWeight.w700),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChips(bool dark) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dateKeys.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == _dateKeys.length) {
            return _chip('create.date_pick'.tr(), false, dark, () {}, icon: Icons.calendar_today);
          }
          return _chip(_dateKeys[i].tr(), i == _dateIndex, dark,
              () => setState(() => _dateIndex = i));
        },
      ),
    );
  }

  Widget _chip(String label, bool active, bool dark, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? _accent : (dark ? InkColors.c900 : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: active ? Colors.white : InkColors.c400), const SizedBox(width: 6)],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : (dark ? InkColors.c200 : InkColors.c700))),
          ],
        ),
      ),
    );
  }

  Widget _seatsRow(bool dark) {
    return _card(
      dark,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_asDriver ? 'create.seats_label_driver'.tr() : 'create.seats_label_passenger'.tr(),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
          SeatsStepper(
            value: _seats,
            max: 7,
            accent: _accent,
            onChanged: (v) => setState(() => _seats = v),
          ),
        ],
      ),
    );
  }

  Widget _priceField(bool dark) {
    return _card(
      dark,
      Row(
        children: [
          Expanded(
            child: Text(_asDriver ? 'create.price_label_driver'.tr() : 'create.price_label_passenger'.tr(),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : InkColors.c900)),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : InkColors.c900),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(color: InkColors.c400),
                suffixText: ' ${'create.som'.tr()}',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prefsSection(bool dark) {
    return _card(
      dark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('create.prefs_title'.tr(),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 4),
          Text(_asDriver ? 'create.prefs_hint_driver'.tr() : 'create.prefs_hint_passenger'.tr(),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in _prefKeys)
                _prefChip(key, _prefs.contains(key), dark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prefChip(String key, bool active, bool dark) {
    return GestureDetector(
      onTap: () => setState(() => active ? _prefs.remove(key) : _prefs.add(key)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accent.withValues(alpha: dark ? 0.25 : 0.12) : (dark ? InkColors.c800 : InkColors.c100),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _accent : Colors.transparent),
        ),
        child: Text(key.tr(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? _accent : (dark ? InkColors.c200 : InkColors.c700))),
      ),
    );
  }

  Widget _sectionLabel(String text, bool dark) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400));
  }

  Widget _card(bool dark, Widget child, {EdgeInsets padding = const EdgeInsets.all(14)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}
