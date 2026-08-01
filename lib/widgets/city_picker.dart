import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../data/kg_cities.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';

/// City selection sheet — stands in for CityAutocomplete until the /cities API
/// lands (ТЗ step 2). Returns the chosen city name or null.
Future<String?> showCityPicker(BuildContext context, {String? title}) {
  return showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CityPickerSheet(),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final results = _query.isEmpty
        ? kgCities
        : kgCities.where((c) => c.toLowerCase().contains(_query.toLowerCase())).toList();

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
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: InkColors.c300, borderRadius: BorderRadius.circular(999))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 15, color: dark ? Colors.white : InkColors.c900),
                decoration: InputDecoration(
                  hintText: 'city_autocomplete.enter_city'.tr(),
                  hintStyle: const TextStyle(color: InkColors.c400),
                  prefixIcon: const Icon(Icons.search, color: InkColors.c400),
                  filled: true,
                  fillColor: dark ? InkColors.c800 : InkColors.c100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.place_outlined, color: InkColors.c400),
                  title: Text(results[i],
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: dark ? Colors.white : InkColors.c900)),
                  onTap: () => Navigator.of(context).pop(results[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
