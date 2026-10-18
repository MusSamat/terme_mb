import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// The app uses `kg` for Kyrgyz (Flutter itself registers it as `ky`).
bool isKg(BuildContext context) => context.locale.languageCode == 'kg';
